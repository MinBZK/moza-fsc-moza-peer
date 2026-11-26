# Cert-attachments op ZAD — peer moza

> Draaiboek voor de operator: de cert-attachments mounten. Uit te voeren nadat de beheerder van
> moza-fsc-testnet de certs heeft uitgegeven (zie `pki/README.md`), en na `upsert-peer.sh apply`.

## UI of API

Bijlagen kunnen in de ZAD-UI, per component, of via de v2 Operations Manager API. Het zijn losse
bestanden op hun `/etc/fsc/...`-pad; een `combined.pem` is niet nodig (modus 2/passthrough).

Via de API (header `X-API-Key`, basis `https://zad.rijksapp.nl/api/v2/projects/mfp-z64`):

- `POST /services/attachments/component/<component>/attachment?rollout=false`, multipart met
  `attachment_id`, `file`, `provide-as=file` en `path`. Een bestand dat meer componenten
  gebruiken (group-root, CRL, internal-root) upload je één keer; daarna koppel je het met
  `reference=<attachment_id>` in plaats van `file`.
- `PUT /services/publish-on-web/config/component/<component>?rollout=false` met
  `{"tls":"passthrough"}`, voor `moza-fscmgr` en `moza-fscinway`.
- `POST /:refresh` rolt alles uit wat met `rollout=false` is opgeslagen; `GET /pending-rollout`
  telt wat nog openstaat.

## Twee cert-mount-valkuilen (bijlagen op `/etc/fsc/...`)

- **Internal-pad** (`/etc/fsc/internal/moza/<endpoint>/`) → de **internal**-cert (getekend door
  de per-peer internal-CA). Group-cert daar mounten geeft `certificate is signed by 'Intermediate
  CA' and not by provided root CA`.
- **Group-pad** (`/etc/fsc/out/moza/<endpoint>/`) → de **group**-cert **inclusief** aangehechte
  intermediate (`out/moza/<endpoint>/cert.pem` bevat 2 PEM-blokken: leaf + intermediate). Een
  leaf-only mount geeft dezelfde keten-fout op de root.
- `TLS_GROUP_ROOT_CERT` = de group-root; internal-`TLS_ROOT_CERT` = de internal-CA-root. Niet
  verwisselen.

## Volgorde

1. **Certs uit moza-fsc-testnet**, niet uit `init-ca.sh` of `issue.sh` hier. De group-certs
   tekent de beheerder van het testnet; de internal-certs komen van de internal-CA van deze peer,
   waarvan de sleutel ook in de geheime repo van het testnet staat.
2. In moza-fsc-testnet: `pki/geheimen.sh ophalen moza` en `pki/zad-bundle.sh moza`. Dat verzamelt
   de upload-klare set in `pki/zad-upload/moza/` met een eigen `MANIFEST.md`
   (bestand → pod-pad → `TLS_*`-env-var). Ruim die map na het uploaden op met
   `pki/geheimen.sh wis moza`.
3. Per component (`moza-fscmgr`, `moza-fscctl`, `moza-fscoutway`, `moza-fscinway`,
   `moza-fsctxlog`), in de ZAD-UI of via de API (zie boven): bijlage toevoegen op het
   `/etc/fsc/...`-pad uit de tabellen hieronder, met de bestandsinhoud uit stap 2's upload-set.
   De paden zijn identiek aan de `TLS_*`-waarden die `upsert-peer.sh` al als `env_vars`/`aliases`
   naar de component stuurt — de attachment moet dus exact op dat pad gemount worden, anders
   faalt de container-boot met een ontbrekend-bestand-fout.

## moza-fscmgr (manager)

| Bijlage-pad (`/etc/fsc/...`) | Bronbestand (`pki/...`) | Env-var op moza-fscmgr |
|-------------------------------|-------------------------------------------|--------------------|
| `ca/root.pem` | `ca/root.pem` | `TLS_GROUP_ROOT_CERT` |
| `out/moza/manager/cert.pem` | `out/moza/manager/cert.pem` | `TLS_GROUP_CERT`, `TLS_GROUP_TOKEN_CERT`, `TLS_GROUP_CONTRACT_CERT` |
| `out/moza/manager/key.pem` | `out/moza/manager/key.pem` | `TLS_GROUP_KEY`, `TLS_GROUP_TOKEN_KEY`, `TLS_GROUP_CONTRACT_KEY` |
| `internal/moza/ca/root.pem` | `internal/moza/ca/root.pem` | `TLS_ROOT_CERT`, `TLS_INTERNAL_UNAUTHENTICATED_ROOT_CERT` |
| `internal/moza/manager/cert.pem` | `internal/moza/manager/cert.pem` | `TLS_CERT`, `TLS_INTERNAL_UNAUTHENTICATED_CERT` |
| `internal/moza/manager/key.pem` | `internal/moza/manager/key.pem` | `TLS_KEY`, `TLS_INTERNAL_UNAUTHENTICATED_KEY` |

## moza-fscctl (controller)

| Bijlage-pad (`/etc/fsc/...`) | Bronbestand (`pki/...`) | Env-var op moza-fscctl |
|-------------------------------|-------------------------------------------|--------------------|
| `internal/moza/ca/root.pem` | `internal/moza/ca/root.pem` | `TLS_ROOT_CERT` |
| `internal/moza/controller/cert.pem` | `internal/moza/controller/cert.pem` | `TLS_CERT` |
| `internal/moza/controller/key.pem` | `internal/moza/controller/key.pem` | `TLS_KEY` |

De controller heeft geen group-cert nodig (hij spreekt geen mesh-verkeer met andere peers, alleen
de eigen manager op de internal-PKI) — vandaar geen `out/moza/controller/*`-rij.

## moza-fscoutway (outway)

| Bijlage-pad (`/etc/fsc/...`) | Bronbestand (`pki/...`) | Env-var op moza-fscoutway |
|-------------------------------|-------------------------------------------|--------------------|
| `ca/root.pem` | `ca/root.pem` | `TLS_GROUP_ROOT_CERT` |
| `out/moza/outway/cert.pem` | `out/moza/outway/cert.pem` | `TLS_GROUP_CERT` |
| `out/moza/outway/key.pem` | `out/moza/outway/key.pem` | `TLS_GROUP_KEY` |
| `internal/moza/ca/root.pem` | `internal/moza/ca/root.pem` | `TLS_ROOT_CERT` |
| `internal/moza/outway/cert.pem` | `internal/moza/outway/cert.pem` | `TLS_CERT`, `TLS_SERVER_CERT` |
| `internal/moza/outway/key.pem` | `internal/moza/outway/key.pem` | `TLS_KEY`, `TLS_SERVER_KEY` |

Het interne cert-paar draagt twee rollen op de outway: als client richting manager, controller en
txlog (`TLS_CERT`/`TLS_KEY`), en als server-cert op de serve-poort `:8443` waar een afnemende
applicatie binnenkomt (`TLS_SERVER_CERT`/`TLS_SERVER_KEY`, actief door `LISTEN_HTTPS=true`). Geen extra
bijlage nodig: het is hetzelfde bestand, en de Service-namen staan al als SAN in het cert.

Een afnemende applicatie heeft datzelfde CA (`internal/moza/ca/root.pem`) als trust anchor nodig
om de outway op `:8443` te vertrouwen. Zodra er een afnemende applicatie is, hangt die bijlage aan
dát component, met dezelfde bron en hetzelfde pad als hierboven.

De bijlage-id's zelf staan niet in dit document — `zadctl attachment list` is daarvoor de bron van
waarheid.

## moza-fscinway (inway)

De inway is een mesh-ingress en heeft daarom — net als moza-fscmgr — een GROUP-cert nodig, plus een
INTERNAL-cert voor de edges naar controller/manager/txlog.

| Bijlage-pad (`/etc/fsc/...`) | Bronbestand (`pki/...`) | Env-var op moza-fscinway |
|-------------------------------|-------------------------------------------|--------------------|
| `ca/root.pem` | `ca/root.pem` | `TLS_GROUP_ROOT_CERT` |
| `out/moza/inway/cert.pem` | `out/moza/inway/cert.pem` | `TLS_GROUP_CERT` |
| `out/moza/inway/key.pem` | `out/moza/inway/key.pem` | `TLS_GROUP_KEY` |
| `internal/moza/ca/root.pem` | `internal/moza/ca/root.pem` | `TLS_ROOT_CERT` |
| `internal/moza/inway/cert.pem` | `internal/moza/inway/cert.pem` | `TLS_CERT` |
| `internal/moza/inway/key.pem` | `internal/moza/inway/key.pem` | `TLS_KEY` |

`out/moza/inway/cert.pem` moet **twee** PEM-blokken bevatten (leaf + intermediate); een
leaf-only mount faalt op de group-root.

## moza-fsctxlog (txlog-api)

txlog spreekt uitsluitend mTLS op de INTERNAL-PKI (geen group-cert — group-agnostische opslag),
net als in de lokale compose.

| Bijlage-pad (`/etc/fsc/...`) | Bronbestand (`pki/...`) | Env-var op moza-fsctxlog |
|-------------------------------|-------------------------------------------|--------------------|
| `internal/moza/ca/root.pem` | `internal/moza/ca/root.pem` | `TLS_ROOT_CERT` |
| `internal/moza/txlog/cert.pem` | `internal/moza/txlog/cert.pem` | `TLS_CERT` |
| `internal/moza/txlog/key.pem` | `internal/moza/txlog/key.pem` | `TLS_KEY` |

## moza-fscpg (self-hosted Postgres) — géén cert, wél een init-script-attachment

De peer draait een eigen postgres-component `moza-fscpg` (self-hosted) i.p.v. ZAD's managed Postgres,
zodat we de schema-init zelf beheren (zie `docs/design.md` + `upsert-peer.sh`). Geen
TLS-attachments (intra-cluster plaintext op `:5432`, `sslmode=disable`), maar wél één attachment: het
init-script dat de search_path-schema's `manager` + `txlog` aanmaakt (de controller maakt z'n eigen schema).

| Bijlage-pad (in de moza-fscpg-container) | Bronbestand (repo) | Werking |
|-------------------------------------|--------------------|---------|
| `/docker-entrypoint-initdb.d/10-schemas.sql` | `deploy/zad/postgres-init.sql` | postgres draait dit éénmalig bij lege PGDATA → `CREATE SCHEMA manager, txlog` |

Verder geen bijlagen op moza-fscpg. Het wachtwoord komt uit `ZAD_PG_PASSWORD` (env bij `apply`, niet in git);
`POSTGRES_USER`/`POSTGRES_DB`/`PGDATA` staan als component-env.

**Persistentie:** zonder gekoppeld persistent volume is de DB ephemeral — bij een nieuwe pod draait het
init-script opnieuw en zijn de tabellen leeg (manager/controller/txlog migreren vanzelf via hun wrapper).
Voor een blijvende peer: een persistent volume koppelen op `/var/lib/postgresql/data`, de map boven
`PGDATA` (`…/data/pgdata`), zodat een `lost+found` op het volume initdb niet tegenhoudt.

**Schema-namen moeten sporen** met `ZAD_MGR_SCHEMA`/`ZAD_TXLOG_SCHEMA` in `upsert-peer.sh` (defaults
`manager`/`txlog`) — dat zijn de search_path-schema's die het init-script aanmaakt. `ZAD_CTL_SCHEMA` is
**leeg** (de controller draait zonder search_path); zet je 'm tóch, dan loopt migratie #1 dirty vast.

## Migraties per component

Alle drie de DB-componenten draaien een migrate-**wrapper** (`migrate up && serve`) — geen losse
migratiestap meer; `upsert-peer.sh` zet de wrapper-images (`{manager,controller,txlog}-migrate`).

- **manager** — `manager-migrate`-wrapper; teller in schema `manager` (search_path), echte tabellen in
  `peers`/`contracts`.
- **controller** — `controller-migrate`-wrapper, **zonder search_path**: de controller maakt z'n eigen
  `controller`-schema aan (schema-gekwalificeerde DDL) en houdt z'n teller in `public`. Mét een vooraf
  aangemaakt `controller`-schema + `search_path=controller` liep migratie #1 dirty vast.
- **txlog** — `txlog-migrate`-wrapper; teller in schema `txlog` (search_path=txlog), echte tabellen in
  `transactionlog`.

**Vastgelopen op `Dirty database version N`?** De vorige migratie brak halverwege af (onderbroken, of
door meerdere replica's die om de migratie-lock vochten). De wrapper herstelt dit niet zelf. Schoon de
migratie-state van dát component op en herstart 'm zodat de wrapper vers migreert — voor de controller
bleek: `DROP SCHEMA controller CASCADE` + de moza-fscctl-component herstarten (schaal desnoods tijdelijk naar
1 replica). Los draaien kan ook, tegen `fsc-moza-moza-fscpg` met de component-DSN (controller **zonder**,
manager/txlog **mét** hun `search_path`):

```sh
/usr/local/bin/controller migrate up --postgres-dsn "postgres://<user>:<pass>@fsc-moza-moza-fscpg:5432/fsc?sslmode=disable"
/usr/local/bin/txlog-api  migrate up --postgres-dsn "postgres://<user>:<pass>@fsc-moza-moza-fscpg:5432/fsc?sslmode=disable&search_path=txlog"
```

## Na het mounten

Herstart (of laat ZAD herstarten na attachment-wijziging) elk component en controleer de boot-log
op een TLS-laadfout — een fout pad of een verwisselde group/internal-cert faalt hard bij startup
("no such file", of een handshake-fout tegen de verkeerde CA). Ga daarna verder met
`verify-zad.md`.

## Bestaande componenten migreren naar de nieuwe env/poorten (multi-poort-fix)

ZAD past `env_vars`/`ports` alléén bij component-**creatie** toe, niet bij een re-POST op een
bestaande component (zie `design.md`). Bestaan de componenten al met de oude (`:443`-)config, dan
zijn er twee routes om de nieuwe interne adressen + poorten door te voeren:

- **Poorten los bijwerken via de API** (env blijft ongemoeid): `PATCH
  /api/v2/projects/mfp-z64/components/<comp>` met body `{"ports":[…]}` (moza-fscmgr `[8443,9443,9444]`,
  moza-fscctl `[8080,9443,9444]`). Zet daarnaast de interne adressen (`MANAGER_ADDRESS_INTERNAL` etc.)
  in de **UI**, want env is UI-beheerd op een bestaande component. Cert-attachments blijven behouden.
- **Component verwijderen + opnieuw aanmaken** (via `upsert-peer.sh apply`, die env+ports in één
  keer zet): dan raak je de cert-attachments kwijt en moet je ze **opnieuw mounten** (deze tabellen).

Na het her-uitgeven van de certs (`issue.sh -f`, want de SAN's zijn gewijzigd) is opnieuw uploaden
sowieso nodig — dus in de praktijk is verwijderen + opnieuw aanmaken + herattachen de schoonste weg.
