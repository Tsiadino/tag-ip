# Pi Admin — Event Definitions

## Purpose

Event definitions are the typed schema used by monitors to produce event occurrences. They form a two-layer system:

1. **Global `EventDefinition`** — the system-wide catalog maintained by Tag-IP. Covers all event types across all monitors (e.g. `DEP`, `MOV`, `ARR`, `PRK`). Events at this level are infrastructure — they can be produced by monitors and used in aggregations without ever being visible to end users.
2. **`OrganizationEventDefinition`** — per-org shadows, and standalone org-specific event types. An org can shadow a global definition (overriding display fields and defining an occurrence rule), or create a new event type that has no global counterpart (typically for level-2+ monitors).

## Visibility Rule

**Only events that have an `OrganizationEventDefinition` record with `enabled = true` are visible in an organization's reports and dashboards.** The absence of a shadow record means the event type is invisible to the org's end users — occurrences may still be produced by global monitors, but they will not appear in any report, dashboard widget, or alert surface.

This is intentional: it allows Tag-IP to define and track system-level events (connectivity loss, GPS signal quality, configuration errors) without polluting the end-user interface. An operator explicitly chooses which event types each org's users will see.

`enabled = false` suppresses visibility even when the record exists — useful for temporarily hiding an event type without deleting its occurrence rule.

## Initialization Flow

After mounting profiles are created for an org, the operator initializes the org's event definitions:

1. The system auto-suggests `OrganizationEventDefinition` candidates derived from the org's mounting profiles — specifically, all global `EventDefinition` records whose `monitor_type` matches a monitor activated by those profiles.
2. The operator reviews the suggested list and enables the events they want visible to end users. System-level events (connectivity, GPS quality, etc.) are visible in this list but disabled by default.
3. For level-1 events, the operator can override display fields and optionally define an `occurrence_rule` to customize the monitor's behavior (e.g. adjust a speed threshold or minimum distance).
4. The operator can then create new `OrganizationEventDefinition` records with custom `occurrence_rule` definitions to activate level-2+ monitors. These are org-specific event types with no global counterpart.
5. On org activation, the Oban worker reads all `OrganizationEventDefinition` records and translates them — together with their `occurrence_rule` — into monitor configurations pushed to the regional Track instance.

**Operators never configure monitors directly.** They define rules; the activation script generates the monitor configuration.

---

## Occurrence Rules

An `occurrence_rule` is a structured map that declares the condition under which an event occurrence is created. Its schema is specific to the `monitor_type` of the event definition.

The activation script validates and translates these rules into monitor configurations on the Track instance. Rules are stored as JSONB in Pi and consumed by the script at activation time.

### Rule Structure

All rules share a top-level `trigger` key identifying the condition type. Remaining keys are trigger-specific.

```json
{
  "trigger": "<trigger_type>",
  ...trigger-specific parameters
}
```

### Example: Speeding event (`OVERSPEED`)

A level-2 speeding event fires when a trackable sustains a speed above a threshold for a minimum duration.

```json
{
  "trigger": "speed_exceeds",
  "threshold_kmh": 80,
  "min_duration_seconds": 5
}
```

The activation script translates this into the `SpeedMonitor` configuration on Track. If different object types warrant different thresholds (trucks vs light vehicles), the org creates separate `OrganizationEventDefinition` records scoped to each object type.

> **OPEN QUESTION #20**: Is `occurrence_rule` always a flat map, or can it be nested (e.g. time-of-day conditions, geofence-scoped thresholds)? Rule complexity directly determines monitor implementation difficulty.

### Known Trigger Types

| Trigger          | Level | Description                                          | Key Parameters                          |
| :--------------- | :---- | :--------------------------------------------------- | :-------------------------------------- |
| `speed_exceeds`    | 2 | Speed above threshold for a minimum duration | `threshold_kmh`, `min_duration_seconds` |
| `no_movement`      | 2 | No movement event for a duration | `duration_minutes` |
| `geofence_enter`   | 2 | Trackable enters a polygon geofence | `feature_collection_id` (must be `:polygon` type) |
| `geofence_exit`    | 2 | Trackable exits a polygon geofence | `feature_collection_id` |
| `geofence_inside`  | 2 | Periodic state report while inside a polygon | `feature_collection_id`, `report_interval_minutes` |
| `poi_near`         | 2 | Trackable is within radius of a POI | `feature_collection_id` (must be `:point` type) |
| `poi_approaching`  | 2 | Trackable is moving toward a POI | `feature_collection_id` |
| `poi_leaving`      | 2 | Trackable was near a POI and is now moving away | `feature_collection_id` |
| `fuel_drop`        | 2 | Fuel level drops more than threshold in a short time | `drop_percent`, `window_minutes` |
| `min_distance`     | 1 | Override minimum distance for movement events | `min_distance_meters` |

Geographic triggers reference a `FeatureCollection` by `feature_collection_id`. The geometry type of the collection must match the trigger type (polygon triggers require `:polygon`, POI triggers require `:point`). See `09-feature-collections.md` for the full geographic layer model.

> **OPEN QUESTION #21**: Full trigger type catalog to be defined with the Track team. This list is illustrative.

---

## Resource: `EventDefinition`

**Module**: `Pi.Events.EventDefinition`
**Domain**: `Pi.Events`

Global catalog of event types. Managed by `superadmin`. Not org-specific.

### Attributes

| Name           | Type                | Constraints                                             | Notes                                                                                                       |
| :------------- | :------------------ | :------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------- |
| `id`           | `uuid_v7`           | primary key                                             |                                                                                                             |
| `code`         | `string`            | required, unique globally, uppercase, max 20, immutable | e.g. `DEP`, `MOV`, `ARR`, `PRK`, `PRK_MOV`                                                                  |
| `name`         | `string`            | required, max 255                                       | Human-readable name e.g. `Départ`                                                                           |
| `definition`   | `string`            | nullable                                                | Detailed description of what this event represents                                                          |
| `category`     | `atom`              | required, see enum below                                | Broad classification of the event nature                                                                    |
| `class`        | `atom`              | required, see enum below                                | Functional class within the category                                                                        |
| `level`        | `integer`           | required, min 1                                         | Monitor level that produces this event. Level 1 = raw physical/system events from mounting profile monitors |
| `level_group`  | `string`            | nullable, max 100                                       | Grouping label within a level e.g. `movement`, `power`, `driver`                                            |
| `monitor_type` | `string`            | required, max 255                                       | The monitor module that creates occurrences e.g. `MovementMonitor`                                          |
| `active`       | `boolean`           | required                                                | Default: `true`                                                                                             |
| `inserted_at`  | `utc_datetime_usec` | auto                                                    |                                                                                                             |
| `updated_at`   | `utc_datetime_usec` | auto                                                    |                                                                                                             |

### Enums

**`category`**

| Value       | Description                                                                        |
| :---------- | :--------------------------------------------------------------------------------- |
| `:physical` | Event derived from physical sensor data (GPS, ignition, fuel, accelerometer)       |
| `:system`   | Event derived from system state (connection lost, GPS signal lost, config applied) |
| `:derived`  | Event computed from other events (movement report, aggregation)                    |

> **OPEN QUESTION #15**: Is this list complete? Other categories (`:driver`, `:geofence`, `:alarm`) may be warranted.

**`class`**

| Value           | Description                                                            |
| :-------------- | :--------------------------------------------------------------------- |
| `:movement`     | Events related to asset motion (departure, movement, arrival, parking) |
| `:power`        | Events related to power supply or ignition                             |
| `:fuel`         | Events related to fuel level or consumption                            |
| `:geofence`     | Events related to geographic zone entry or exit                        |
| `:driver`       | Events related to driver identification                                |
| `:alarm`        | Events related to alerts and alarms (towing, harsh braking, impact)    |
| `:connectivity` | Events related to tracker connectivity and signal quality              |

> **OPEN QUESTION #16**: Confirm the full class list. Class determines UI grouping and filtering in Track.

### Actions

**`:create`**

- Arguments: all except `id`, `inserted_at`, `updated_at`
- `code` is immutable after creation
- Policy: `superadmin` only

**`:update`**

- Updatable fields: `name`, `definition`, `category`, `class`, `level`, `level_group`, `monitor_type`, `active`
- Policy: `superadmin` only

**`:read`** (`:list`, `:get`)

- `:list` — filterable by `category`, `class`, `level`, `monitor_type`, `active`
- `:get` — by `id` or `code`
- Policy: `superadmin`; `org_admin` and `readonly` can list active definitions for reference

### Business Rules

1. `code` is the stable cross-system identifier used in monitor logic, aggregation queries, and Track. It must never change after creation.
2. Deactivating a global definition does not remove org shadows — existing records are retained but the activation script must stop instantiating monitors for this event type. **OPEN QUESTION #17**: How is deactivation propagated to already-running regional instances?

---

## Resource: `OrganizationEventDefinition`

**Module**: `Pi.Events.OrganizationEventDefinition`

Two modes:

- **Shadow mode** (`event_definition_id` is set): overrides fields of a global `EventDefinition` and/or adds an `occurrence_rule`.
- **Standalone mode** (`event_definition_id` is null): defines a new event type specific to this org, with its own `code` and a mandatory `occurrence_rule`. Used for level-2+ custom events (e.g. speeding, idle, geofence alarms).

### Attributes

| Name                  | Type                | Constraints                                                                    | Notes                                                                                                                                                                           |
| :-------------------- | :------------------ | :----------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`                  | `uuid_v7`           | primary key                                                                    |                                                                                                                                                                                 |
| `organization_id`     | `uuid`              | required, FK → `Organizations.Organization`                                    |                                                                                                                                                                                 |
| `event_definition_id` | `uuid`              | nullable, FK → `EventDefinition`                                               | Null for standalone org-specific events                                                                                                                                         |
| `code`                | `string`            | required when `event_definition_id` is null; unique per org; uppercase, max 20 | e.g. `OVERSPEED`, `IDLE_30M`. Inherited from global definition when shadowing.                                                                                                  |
| `name`                | `string`            | nullable, max 255                                                              | Overrides global `name` if set; required when standalone                                                                                                                        |
| `definition`          | `string`            | nullable                                                                       | Overrides global `definition` if set                                                                                                                                            |
| `category`            | `atom`              | nullable                                                                       | Overrides global `category` if set; required when standalone                                                                                                                    |
| `class`               | `atom`              | nullable                                                                       | Overrides global `class` if set; required when standalone                                                                                                                       |
| `level`               | `integer`           | nullable, min 1                                                                | Overrides global `level` if set; required when standalone                                                                                                                       |
| `level_group`         | `string`            | nullable, max 100                                                              | Overrides global `level_group` if set                                                                                                                                           |
| `occurrence_rule`     | `:map`              | nullable                                                                       | Structured rule defining when an occurrence is created. Required for standalone events. For shadows, overrides the default monitor behavior. Schema is `monitor_type`-specific. |
| `alert_mode`          | `atom`              | required, one of `:none`, `:alert`, `:report`, `:both`                        | Whether this event definition generates notifications, and of which kind. Default: `:none`. See Alert Model section below.                                                      |
| `enabled`             | `boolean`           | required                                                                       | `false` = invisible in reports and dashboards, no org-scoped monitor instantiated. Default: `true`                                                                              |
| `author_id`           | `uuid`              | required, FK → `Accounts.User`                                                 |                                                                                                                                                                                 |
| `inserted_at`         | `utc_datetime_usec` | auto                                                                           |                                                                                                                                                                                 |
| `updated_at`          | `utc_datetime_usec` | auto                                                                           |                                                                                                                                                                                 |

### Constraints

- Unique per `(organization_id, event_definition_id)` when shadowing.
- Unique per `(organization_id, code)` for standalone events.

### Relationships

| Type         | Name               | Target                       |
| :----------- | :----------------- | :--------------------------- |
| `belongs_to` | `organization`     | `Organizations.Organization` |
| `belongs_to` | `event_definition` | `EventDefinition` (nullable) |
| `belongs_to` | `author`           | `Accounts.User`              |

### Actions

**`:enable`** (custom upsert)

- Creates or updates a shadow for a given `(organization_id, event_definition_id)`, setting `enabled = true`
- For auto-suggested events during initialization: creates the shadow with defaults if it does not exist
- Policy: `superadmin` only

**`:create_standalone`** (custom create)

- Arguments: `organization_id`, `code`, `name`, `definition`, `category`, `class`, `level`, `level_group`, `occurrence_rule`
- `event_definition_id` is null
- `occurrence_rule` is required
- Policy: `superadmin` only

**`:update`**

- Updatable fields: `name`, `definition`, `category`, `class`, `level`, `level_group`, `occurrence_rule`, `alert_mode`, `enabled`
- Policy: `superadmin` only

**`:read`** (`:list`, `:get`, `:resolved`)

- `:list` — all records for a given `organization_id`, filterable by `enabled`, `level`, `class`
- `:get` — by `id` or by `(organization_id, code)`
- `:resolved` — merged view of global fields + org overrides; for shadows only. Used by the activation script and UI.
- Policy: `superadmin`; `org_admin` and `readonly` for their own org

### Business Rules

1. **Visibility gate**: a record with `enabled = true` is required for an event type to appear in the org's reports and dashboards. No record or `enabled = false` = invisible to end users regardless of occurrence production.
2. **Operator-defined rules, not monitor configs**: operators define `occurrence_rule`; the activation script translates these into monitor configurations. Operators never interact with monitor internals.
3. Setting `occurrence_rule` on a shadow implies an org-scoped monitor instance runs alongside the global monitor. Both produce occurrences independently. Duplicates are intentional and beneficial for aggregation at different scopes.
4. `occurrence_rule` is validated against the trigger schema declared by the relevant `monitor_type` at save time. An invalid rule is rejected with field-level errors.
5. Standalone events (null `event_definition_id`) require `occurrence_rule` — they have no global monitor to fall back to.

---

## Alert Model

The `alert_mode` field on `OrganizationEventDefinition` controls whether an event occurrence generates notifications and of which kind.

### Modes

| Value     | Trigger point        | Timing         | Description                                                                                                                 |
| :-------- | :------------------- | :------------- | :-------------------------------------------------------------------------------------------------------------------------- |
| `:none`   | —                    | —              | No notification. Event is tracked and visible in reports/dashboards but generates no alert.                                 |
| `:alert`  | Start of event       | Real-time      | Notification fired when the event begins. Suitable for immediate awareness (e.g. speeding started, geofence entered).       |
| `:report` | End of event         | Deferred       | Notification fired when the event ends, carrying metadata (duration, distance, etc.). May arrive with delay. Re-sent on restitution (see below). |
| `:both`   | Start and end        | Mixed          | Fires both an `:alert` at event start and a `:report` at event end.                                                        |

### Report Metadata

A `:report` notification is enriched with event-end metadata. The available fields depend on the event type and monitor. Common fields:

- `duration_seconds` — elapsed time from start to end
- `distance_meters` — distance covered during the event (for movement-type events)
- `max_value` — peak value recorded (e.g. max speed for an `OVERSPEED` event)

> **OPEN QUESTION #22**: Full report metadata schema per monitor type to be confirmed with the Track team.

### Restitution

All trackers are configured in LIFO (Last In, First Out) mode. When GPS points arrive out of order (e.g. delayed transmission, reconnection after blackout), the system reprocesses the affected time window. Any event whose boundaries change as a result of reprocessing generates a new `:report` notification — this is the restitution re-send.

Consumers of `:report` notifications must therefore handle duplicates or corrections for the same logical event occurrence. The Track API will expose an `occurrence_id` stable across restitution re-sends to allow idempotent processing.

> **OPEN QUESTION #23**: Should restituted reports carry an explicit `is_restitution: true` flag, or is the `occurrence_id` + timestamp sufficient for consumers to detect them?

---

## Effective Definition Resolution

For shadow records, the effective definition is resolved as:

```
effective_field = organization_event_definition[field] || event_definition[field]
```

Applies to: `name`, `definition`, `category`, `class`, `level`, `level_group`. The fields `occurrence_rule`, `enabled`, and `code` (for standalone) have no global equivalent.

> `# PERF:` The `:resolved` action must use a single LEFT JOIN + COALESCE query. Never resolve in application code — N+1 on a full org definition list will be severe.

---

## Relationship to Monitors and Activation

The event definition layer in Pi is a **configuration surface**. Actual monitor execution lives on the regional Track instance.

At org activation, the `ActivateOrganizationConfig` Oban worker (or a dedicated sub-worker) reads all `OrganizationEventDefinition` records for the org and:

1. For each `enabled = true` shadow **without** `occurrence_rule`: ensures the global monitor is active for this org on Track (no custom config needed).
2. For each `enabled = true` shadow **with** `occurrence_rule`: pushes an org-scoped monitor configuration to Track, parameterized by the rule.
3. For each `enabled = true` standalone: pushes a new org-specific monitor configuration to Track.
4. For each `enabled = false`: ensures no org-scoped monitor is running for this event type on Track.

> `# ALT:` OQ#19 (push vs pull) is partially resolved by this model — the activation script pushes. However, incremental updates (enabling/disabling a single event after initial activation) may warrant a lightweight push mechanism that does not require a full re-activation.

---

## Examples

### `MovementMonitor` global event definitions (level 1)

| Code      | Name                | Category    | Class       | Level | Level Group |
| :-------- | :------------------ | :---------- | :---------- | :---- | :---------- |
| `DEP`     | Départ              | `:physical` | `:movement` | 1     | `movement`  |
| `MOV`     | Déplacement         | `:derived`  | `:movement` | 1     | `movement`  |
| `PRK_MOV` | Déplacement parking | `:derived`  | `:movement` | 1     | `movement`  |
| `ARR`     | Arrivée             | `:physical` | `:movement` | 1     | `movement`  |
| `PRK`     | Arrêt               | `:physical` | `:movement` | 1     | `movement`  |

### Global geo event definitions (level 2)

| Code | Name | Category | Class | Level | Level Group |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `GEO_ENTER` | Entrée zone | `:physical` | `:geofence` | 2 | `geofence` |
| `GEO_EXIT` | Sortie zone | `:physical` | `:geofence` | 2 | `geofence` |
| `GEO_INSIDE` | Dans la zone | `:derived` | `:geofence` | 2 | `geofence` |
| `GEO_NEAR` | Proximité POI | `:physical` | `:geofence` | 2 | `poi` |
| `GEO_APPROACHING` | Approche POI | `:physical` | `:geofence` | 2 | `poi` |
| `GEO_LEAVING` | Départ POI | `:physical` | `:geofence` | 2 | `poi` |

These codes are the global definitions. An org makes them visible by creating `OrganizationEventDefinition` records with the appropriate `occurrence_rule` referencing a `feature_collection_id`.

---

### Standalone org event: speeding (level 2)

An org operating light vehicles wants to detect speeding above 80 km/h sustained for at least 5 seconds:

```json
{
  "organization_id": "<uuid>",
  "event_definition_id": null,
  "code": "OVERSPEED",
  "name": "Excès de vitesse",
  "category": "physical",
  "class": "alarm",
  "level": 2,
  "level_group": "speed",
  "occurrence_rule": {
    "trigger": "speed_exceeds",
    "threshold_kmh": 80,
    "min_duration_seconds": 5
  },
  "enabled": true
}
```

The activation script translates this into a `SpeedMonitor` configuration on Track scoped to this org.

### Shadow with rule override: minimum distance for boats

An org operating boats overrides the minimum distance threshold for `MOV`:

```json
{
  "organization_id": "<uuid>",
  "event_definition_id": "<MOV global id>",
  "occurrence_rule": {
    "trigger": "min_distance",
    "min_distance_meters": 500
  },
  "enabled": true
}
```

---

## Open Questions

| #   | Question                                                                                                                                         | Impact                                                |
| :-- | :----------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------- |
| 15  | Is the `category` enum complete?                                                                                                                 | Affects monitor classification and UI grouping        |
| 16  | Is the `class` enum complete?                                                                                                                    | Affects UI filtering in Track and Pi                  |
| 17  | How is global `EventDefinition` deactivation propagated to already-running regional instances?                                                   | Requires coordination with Track deployment model     |
| 18  | ~~Where is the filter schema defined?~~ **Resolved**: `occurrence_rule` schema is defined per `monitor_type` in Pi, validated at save time.      | —                                                     |
| 19  | ~~Push vs pull?~~ **Partially resolved**: activation script pushes. Incremental updates post-activation still need a lightweight sync mechanism. | Affects UC-02 (config update) scope                   |
| 20  | Can `occurrence_rule` be nested (time-of-day conditions, geofence-scoped thresholds)?                                                            | Determines rule expressiveness and monitor complexity |
| 21  | Full trigger type catalog to be defined with Track team                                                                                          | Required before activation script implementation      |
