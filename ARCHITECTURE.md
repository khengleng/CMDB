# NetBox Architecture Overview & Duplo CMDB Customization Plan

## 1. Technology Stack

| Layer | Technology |
|-------|-----------|
| **Language** | Python 3.12+ |
| **Framework** | Django 5.2 |
| **Database** | PostgreSQL (via psycopg3) |
| **Cache/Queue** | Redis (django-redis + django-rq) |
| **REST API** | Django REST Framework (DRF) + drf-spectacular (OpenAPI 3) |
| **GraphQL** | Strawberry GraphQL + strawberry-graphql-django |
| **Templating** | Django Templates + Jinja2 (device config rendering) |
| **Frontend** | Bootstrap 5 + HTMX (django-htmx) |
| **Auth** | Django built-in + social-auth (SSO/OAuth) |
| **WSGI Server** | Gunicorn |

---

## 2. Project Structure

```
CMDB/
├── netbox/                     # Main Django project root
│   ├── manage.py               # Django management script
│   ├── netbox/                 # Core Django project settings & config
│   │   ├── settings.py         # Main settings (980 lines, all config params)
│   │   ├── urls.py             # Root URL routing
│   │   ├── wsgi.py             # WSGI entry point
│   │   ├── configuration_example.py  # Config template (copy to configuration.py)
│   │   ├── middleware.py       # Custom middleware (auth, maintenance, etc.)
│   │   ├── api/                # Global API config (root view, auth)
│   │   ├── plugins/            # Plugin framework (PluginConfig base class)
│   │   ├── graphql/            # Global GraphQL schema
│   │   ├── views/              # Global views (home, search, errors)
│   │   ├── models/             # Base model classes (PrimaryModel, etc.)
│   │   └── navigation/         # Navigation menu structure
│   │
│   ├── dcim/                   # Data Center Infrastructure Management (157 files)
│   │   ├── models/
│   │   │   ├── sites.py        # Region → SiteGroup → Site → Location
│   │   │   ├── racks.py        # Rack, RackRole, RackReservation
│   │   │   ├── devices.py      # Manufacturer, DeviceType, DeviceRole, Device, Platform
│   │   │   ├── device_components.py     # Interface, ConsolePort, PowerPort, etc.
│   │   │   ├── device_component_templates.py  # Templates for device components
│   │   │   ├── cables.py       # Cable, CablePath, CableTermination
│   │   │   ├── modules.py      # Module, ModuleType, ModuleBay
│   │   │   └── power.py        # PowerPanel, PowerFeed
│   │   ├── views.py            # DCIM views (155K - largest file)
│   │   ├── filtersets.py       # Filters for DCIM objects (95K)
│   │   ├── api/                # REST API serializers, views, URLs
│   │   ├── graphql/            # GraphQL types & schema
│   │   ├── tables/             # HTML table definitions
│   │   ├── forms/              # Django forms (create, edit, bulk, filter)
│   │   └── migrations/         # Database migrations (60 files)
│   │
│   ├── ipam/                   # IP Address Management (96 files)
│   │   ├── models/
│   │   │   ├── ip.py           # IPAddress, Prefix, IPRange, Aggregate, RIR, Role
│   │   │   ├── vlans.py        # VLAN, VLANGroup, VLANTranslationPolicy
│   │   │   ├── vrfs.py         # VRF, RouteTarget
│   │   │   ├── asns.py         # ASN, ASNRange
│   │   │   ├── fhrp.py         # FHRPGroup, FHRPGroupAssignment
│   │   │   └── services.py     # Service, ServiceTemplate
│   │   └── ...
│   │
│   ├── circuits/               # Circuit management (62 files)
│   │   ├── models/             # Provider, Circuit, CircuitType, CircuitTermination
│   │   └── ...
│   │
│   ├── virtualization/         # Virtual machines (63 files)
│   │   ├── models/
│   │   │   ├── clusters.py     # Cluster, ClusterGroup, ClusterType
│   │   │   └── virtualmachines.py  # VirtualMachine, VMInterface
│   │   └── ...
│   │
│   ├── vpn/                    # VPN management (52 files)
│   │   ├── models/             # Tunnel, TunnelGroup, TunnelTermination, IKE/IPSec
│   │   └── ...
│   │
│   ├── wireless/               # Wireless management (49 files)
│   │   ├── models/             # WirelessLAN, WirelessLANGroup, WirelessLink
│   │   └── ...
│   │
│   ├── tenancy/                # Multi-tenancy (55 files)
│   │   ├── models/
│   │   │   ├── tenants.py      # Tenant, TenantGroup
│   │   │   └── contacts.py     # Contact, ContactGroup, ContactRole, ContactAssignment
│   │   └── ...
│   │
│   ├── extras/                 # Extensibility features (148 files)
│   │   ├── models/
│   │   │   ├── customfields.py # CustomField, CustomFieldChoiceSet
│   │   │   ├── tags.py         # Tag, TaggedItem
│   │   │   ├── configs.py      # ConfigContext, ConfigTemplate
│   │   │   ├── scripts.py      # Script, ScriptModule
│   │   │   ├── notifications.py # Notification, NotificationGroup
│   │   │   └── models.py       # Bookmark, EventRule, ExportTemplate, ImageAttachment, Webhook, etc.
│   │   ├── scripts.py          # Script execution engine
│   │   ├── webhooks.py         # Webhook processing
│   │   └── ...
│   │
│   ├── users/                  # User management (62 files)
│   ├── account/                # User account/profile
│   ├── core/                   # Core utilities (91 files)
│   │   ├── models/
│   │   │   ├── data.py         # DataSource, DataFile
│   │   │   ├── jobs.py         # Job (background task tracking)
│   │   │   └── change_logging.py  # ObjectChange
│   │   └── ...
│   │
│   ├── utilities/              # Shared utilities (144 files)
│   ├── templates/              # Django HTML templates (346 files)
│   ├── project-static/         # Static assets (JS, CSS, images)
│   └── translations/           # i18n translations (32 files)
│
├── docs/                       # MkDocs documentation (295 files)
├── contrib/                    # Deployment configs (Apache, nginx, systemd, Gunicorn)
├── scripts/                    # Utility scripts
├── requirements.txt            # Pinned Python dependencies
└── upgrade.sh                  # Upgrade helper script
```

---

## 3. Core Architecture Patterns

### 3.1 Model Hierarchy
Every data model in NetBox inherits from a base hierarchy:
```
BaseModel (abstract)
└── ChangeLoggedModel (tracks creation/modification)
    └── PrimaryModel (adds: tags, custom fields, comments, bookmarks, journal)
        └── App-specific models (Device, Site, IPAddress, etc.)
```

### 3.2 Standard Django App Pattern
Each app (`dcim`, `ipam`, `circuits`, etc.) follows the same structure:
- **`models/`** — Django ORM models
- **`api/`** — DRF serializers, viewsets, and URL routes
- **`graphql/`** — Strawberry GraphQL types and filters
- **`forms/`** — Create/edit forms, bulk edit, filter forms, CSV import forms
- **`tables/`** — django-tables2 table definitions
- **`filtersets.py`** — django-filter FilterSet classes
- **`views.py`** — Django class-based views (list, detail, create, edit, delete, bulk)
- **`urls.py`** — URL patterns
- **`search.py`** — Search index definitions
- **`tests/`** — Unit tests

### 3.3 Plugin System
NetBox has a **first-class plugin system** that allows adding new:
- Models & database tables
- REST API endpoints
- GraphQL types
- Views & templates
- Navigation menu items
- Custom fields & validators
- Background jobs

Plugins are Django apps that subclass `PluginConfig` and register via `PLUGINS` in configuration.

### 3.4 API Architecture
- **REST API** — Full CRUD at `/api/<app>/` (DRF ViewSets + OpenAPI schema at `/api/schema/`)
- **GraphQL** — Read-only queries at `/graphql/` (Strawberry)
- **Authentication** — Token-based (API tokens) or session-based (web UI)

### 3.5 Multi-Tenancy
Built-in via the `tenancy` app. Almost every object can be assigned to a `Tenant`, enabling data segregation by customer/department.

---

## 4. Duplo CMDB Customization Plan

### What is Duplo?
[Duplo](https://duplocloud.com/) is a DevOps automation platform that provisions and manages cloud infrastructure (AWS, Azure, GCP). A "Duplo CMDB" would extend NetBox to serve as the **source of truth for Duplo-managed infrastructure**.

### 4.1 Phase 1: Core Branding & Configuration
| Task | Details |
|------|---------|
| Rename branding | Change "NetBox" → "Duplo CMDB" in templates, titles, and navigation |
| Custom configuration | Create `configuration.py` with Duplo-specific defaults |
| Custom dashboard | Update home dashboard to show Duplo-relevant widgets |

### 4.2 Phase 2: Cloud Infrastructure Models (New Django App: `cloud`)
NetBox focuses on **physical** infrastructure (racks, cables, power). For Duplo, we need **cloud-native** models:

```python
# Proposed new models for netbox/cloud/ app

class CloudProvider        # AWS, Azure, GCP (extends existing concepts)
class CloudAccount         # AWS Account, Azure Subscription, GCP Project
class DuploTenant          # Duplo Tenant (maps to cloud account segmentation)
class DuploInfrastructure  # Duplo Infrastructure (VPC/network layer)
class DuploService         # ECS, EKS, RDS, Lambda, S3, etc.
class DuploHost            # EC2 instances, Azure VMs (links to Device/VirtualMachine)
class CloudRegion          # AWS Region → maps to NetBox Region
class CloudVPC             # VPC/VNet (links to IPAM Prefix)
class CloudSubnet          # Subnet (links to IPAM Prefix)
class SecurityGroup        # Firewall rules
class LoadBalancer         # ALB, NLB, etc.
class DNSRecord            # Route53, Azure DNS, etc.
class CloudDatabase        # RDS, Azure SQL, Cloud SQL
class ContainerCluster     # EKS, AKS, GKE (extends virtualization.Cluster)
class ContainerService     # ECS Service, K8s Deployment
class ServerlessFunction   # Lambda, Azure Functions, Cloud Functions
```

### 4.3 Phase 3: Duplo API Integration
| Feature | Details |
|---------|---------|
| **Duplo Sync Job** | Background job (django-rq) to sync infrastructure from Duplo API |
| **Auto-discovery** | Periodically pull tenant, host, and service data from Duplo |
| **Bidirectional sync** | Push changes from CMDB back to Duplo (optional) |
| **Webhook events** | Trigger webhooks when Duplo infrastructure changes |

### 4.4 Phase 4: Enhanced Visualization
| Feature | Details |
|---------|---------|
| **Cloud topology map** | Visual diagram of VPCs, subnets, and services |
| **Cost tracking** | Link infrastructure to cost data |
| **Compliance dashboard** | Security group audit, unused resource detection |
| **Duplo tenant overview** | Per-tenant infrastructure summary |

### 4.5 Integration Points with Existing NetBox
| NetBox Module | Duplo CMDB Integration |
|---------------|----------------------|
| **DCIM (Sites)** | Map Duplo infrastructure to physical sites/regions |
| **IPAM** | Auto-populate VPC CIDRs, subnet ranges, and IP allocations |
| **Virtualization** | Map cloud instances to VirtualMachine objects |
| **Tenancy** | Map Duplo tenants to NetBox tenants |
| **Circuits** | Track cloud interconnects (Direct Connect, ExpressRoute) |
| **Extras (Custom Fields)** | Add Duplo-specific metadata to existing objects |
| **Extras (Webhooks)** | Notify external systems of CMDB changes |

---

## 5. Getting Started

### Prerequisites
- Python 3.12+
- PostgreSQL 14+
- Redis 7+

### Quick Start (Development)
```bash
cd /Users/mlh/NetBox-Duplo-CMDB/CMDB

# 1. Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Create configuration
cp netbox/netbox/configuration_example.py netbox/netbox/configuration.py
# Edit configuration.py: set ALLOWED_HOSTS, DATABASE, REDIS, SECRET_KEY

# 4. Run database migrations
cd netbox
python manage.py migrate

# 5. Create superuser
python manage.py createsuperuser

# 6. Collect static files
python manage.py collectstatic --no-input

# 7. Start development server
python manage.py runserver 0.0.0.0:8000
```

### Syncing with Upstream
```bash
git fetch upstream
git merge upstream/main
# Resolve any conflicts, then:
git push origin main
```
