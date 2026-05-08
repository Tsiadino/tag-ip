# PiEvents - Cas d'Usage (Use Cases)

## Objectif du Projet

PiEvents est un système de **gestion et surveillance d'événements** destiné aux organisations souhaitant monitorer leur parc de véhicules ou d'équipements via des alertes personnalisées.

---

## Cas d'Usage Principaux

### 1. Gestion Multi-Organisations

**Contexte** : Une entreprise de télématique gère plusieurs clients (organisations).

**Exemple** :
- **Demo Corp** (slug: `demo_corp`) - Client principal
- **Org 1** à **Org 5** - Nouveaux clients
- Chaque organisation a ses propres paramètres d'alertes

**Fonctionnalité** :
```elixir
# Créer une nouvelle organisation
PiEvents.Accounts.Organization
|> Ash.Changeset.for_create(:create, %{
  name: "Transport Dupont",
  slug: "transport_dupont",
  config: %{}
})
|> Ash.create!()
```

---

### 2. Import et Gestion des Événements

**Contexte** : Import d'un catalogue d'événements depuis un fichier CSV (3,341 événements).

**Structure du CSV** (`priv/data/event_descriptions.csv`) :
```csv
id,code,name,description,category,type,organization_source,equipment_id,level,source_type,family
a9718705-b680-41ee-bc09-d9bbb321ca80,EE.COS.CANVL.CMC.OSPD.90.R,infraction,Vitesse > 90 km/h,[VL] Survitesse,...
```

**Événements importés** :
- **Infractions** : Excès de vitesse (ex: `EE.COS.CANVL.CMC.OSPD.90.R` - Vitesse > 90 km/h)
- **Sécurité** : Freinage brusque, accélérations dangereuses
- **Information** : Arrivées, départs, arrêts
- **Personnalisés** : Événements spécifiques par organisation

---

### 3. Configuration des Événements par Organisation

**Contexte** : Chaque organisation configure quels événements déclencher des alertes.

**Exemple de configuration** :
```elixir
# Activer l'alerte pour "Vitesse > 90 km/h" pour Demo Corp
org = PiEvents.Accounts.Organization.by_slug!("demo_corp")
event_def = PiEvents.Events.EventDefinition |> Ash.read!(filter: [code: "EE.COS.CANVL.CMC.OSPD.90.R"]) |> List.first()

PiEvents.Events.OrganizationEvent
|> Ash.Changeset.for_create(:create, %{
  organization_id: org.id,
  event_definition_id: event_def.id,
  enabled: true,
  alert_mode: "alert",  # Envoie une alerte réelle
  occurrence_rule: %PiEvents.Events.OccurrenceRule{
    type: :threshold,
    min_duration: 300  # 5 minutes minimum
  }
})
|> Ash.create!()
```

**Statut actuel** :
- **2,389 événements activés** par organisation
- **952 événements désactivés**
- **Alert mode** : `"alert"` pour infractions, `"dashboard"` pour info

---

### 4. Dashboard en Temps Réel

**URL** : `http://localhost:4000/dashboard`

**Fonctionnalités** :
1. **Vue d'ensemble** : Liste de tous les événements système
2. **Filtrage** : Par catégorie (tous, infraction, information)
3. **Recherche** : Par code ou nom d'événement
4. **Toggle** : Activer/désactiver un événement en un clic

**Interface** :
```heex
<div :for={event <- @events}>
  <div class="event-card">
    <span class="badge">{event.category}</span>
    <h3>{event.name}</h3>
    <p>{event.description}</p>
    <button phx-click="toggle_event">
      <%= if event.enabled, do: "Désactiver", else: "Activer" %>
    </button>
  </div>
</div>
```

---

### 5. Initialisation et Provisioning

**URL** : `http://localhost:4000/init`

**Cas d'usage** :
1. **Première connexion** : Provisioning automatique des 3,341 événements
2. **Configuration globale** : Activer/désactiver tous les événements d'un coup
3. **Statistiques** : Voir le nombre d'événements actifs/inactifs

**Actions disponibles** :
- **"Activer tous"** : Active tous les événements
- **"Désactiver tous"** : Désactive tous les événements
- **Toggle individuel** : Configure chaque événement séparément

---

### 6. Système d'Alertes et Monitoring

**URL** : `http://localhost:4000/monitoring`

**Composants** :
1. **MonitoringConfig** : Configuration par organisation
   - Intervalle de polling (défaut: 30s)
   - Webhook URL (ex: `https://webhook.site/demo_corp`)
   - Email d'alerte (ex: `admin@demo.com`)
   - Logs activés/désactivés

2. **AlertLog** : Historique des alertes déclenchées
3. **EventAuditLog** : Traçabilité des actions (qui a activé/désactivé quoi)

**Worker Oban** :
```elixir
# Déclenchement manuel d'un test
PiEvents.Monitoring.MonitorWorker.new(%{organization_id: org_id})
|> Oban.insert()
```

---

### 7. Cas d'Usage Concret : Transport de Marchandises

**Scénario** :
1. **Org 1** (Transport de marchandises) surveille :
   - Vitesse > 90 km/h sur autoroute (alerte)
   - Freinage brusque (alerte)
   - Arrivée/départ (dashboard seulement)

2. **Org 2** (Transport urbain) surveille :
   - Vitesse > 60 km/h en ville (alerte)
   - Conduite de nuit (alerte)
   - Arrêts non autorisés (dashboard)

**Configuration différenciée** :
```elixir
# Org 1 - Plus permissive
Org 1 -> Vitesse > 90 km/h = ALERTE
Org 1 -> Freinage = ALERTE

# Org 2 - Plus stricte
Org 2 -> Vitesse > 60 km/h = ALERTE
Org 2 -> Conduite de nuit = ALERTE
```

---

### 8. Import Massif via CSV

**Processus** :
1. **Fichier source** : `priv/data/event_descriptions.csv` (3341 événements)
2. **Provisioning** : Via `PiEvents.Events.Provisioning.provision_from_csv/1`
3. **Liaison** : Création automatique des OrganizationEvents pour chaque org

**Résultat** :
```
6 organisations × 3,341 événements = 20,046 OrganizationEvents
Chaque événement a :
  - enabled: true/false selon la catégorie
  - alert_mode: "alert" ou "dashboard"
  - occurrence_rule: règles personnalisables
```

---

### 9. Architecture Technique (Résumé)

```
┌─────────────────────┐     ┌──────────────────────────┐
│   Organizations   │─────│  OrganizationEvents    │
│   (6 orgs)       │ 1  │  (20,046 records)  │
└────────┬────────────┘     └────────┬───────────────┘
         │                          │
         │                          │ n
         │                          │
         │                   ┌──────┴───────────────┐
         │                   │  EventDefinitions   │
         │                   │  (3,341 events)    │
         │                   └───────────────────────┘
         │
         └──> MonitoringConfig (1 par org)
         └──> AlertLog (historique)
         └──> EventAuditLog (traçabilité)
```

---

### 10. Bénéfices pour l'Utilisateur Final

1. **Vue centralisée** : Tous les événements d'une organisation en un clin d'œil
2. **Alertes en temps réel** : Notification immédiate en cas d'infraction
3. **Configuration flexible** : Activer/désactiver selon les besoins
4. **Traçabilité** : Audit log complet des actions
5. **Multi-tenancy** : Isolation parfaite entre organisations
6. **Import simplifié** : 3,341 événements pré-configurés via CSV

---

## Résumé

PiEvents permet aux **entreprises de télématique** de :
- Gérer **plusieurs clients** (organisations) avec des configurations indépendantes
- **Importer un catalogue** d'événements depuis un CSV (3,341 événements)
- **Configurer des alertes** personnalisées par organisation
- **Monitorer en temps réel** avec dashboard et notifications
- **Tracer toutes les actions** (audit trail)

**Statut actuel** : ✅ **Production-ready** avec 6 organisations, 3,341 événements, et documentation complète.
