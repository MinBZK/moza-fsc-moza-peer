# ZAD-deploy — peer moza

ZAD-rollout van de FSC-peer `moza` (manager `moza-fscmgr`, controller `moza-fscctl`, outway
`moza-fscoutway`, inway `moza-fscinway`, txlog `moza-fsctxlog`, self-hosted Postgres `moza-fscpg`)
in het **eigen ZAD-project `MOZa FSC Peer`** (technische naam **`mfp-z64`**), deployment
**`fsc-moza`**. De peer heeft nog geen gepubliceerde dienst en geen contract: de inway staat klaar
om diensten aan te bieden, de outway om diensten af te nemen. Bouwt voort op `pki/` (certs) en
`deploy/local/` (lokale compose-proof van dezelfde peer).

> **Certs komen uit `moza-fsc-testnet`.** De group-certs voor ZAD geeft de beheerder van het
> testnet uit; zie `pki/README.md`. Draai voor ZAD hier niet `pki/init-ca.sh` of `pki/issue.sh`,
> en zet de CA-sleutel van het testnet niet in deze repo.

**Stand (26 november 2026).** De peer draait op ZAD en is aangemeld bij de directory. Stap 1–7
zijn gedaan: de certs in moza-fsc-testnet, de componenten via de v2-API met dezelfde env als
`upsert-peer.sh`. Draai `apply` niet opnieuw: de componenten bestaan al, en env wordt alleen bij het
aanmaken toegepast. De certs zijn getekend uit `pki/peers/moza/`, met `O=MOZa`. Stap 9 en 10
staan nog open.

## Inhoud

| Bestand | Rol |
|---------|-----|
| `upsert-peer.sh` | `validate`/`plan`/`apply` tegen de ZAD v2 Operations Manager API — voor de eenmalige component-creatie (env/ports) en voor debugging. |
| `cert-manifest.md` | Runbook: welk cert-bestand op welk `/etc/fsc/...`-pad, per component (bijlagen via UI of API). |
| `postgres-init.sql` | Init-script voor `moza-fscpg` (schema's `manager` en `txlog`); bijlage op `/docker-entrypoint-initdb.d/10-schemas.sql`. |
| `verify-zad.md` | Runbook: announce en vervolgstappen ná een geslaagde apply, + de acceptatiecriteria. |
| `../../.github/workflows/deploy.yml` | Doorlopende image-tag-updates van de zes componenten (handmatig te starten). Niet de eenmalige creatie (die doet `upsert-peer.sh`). |

## Volgorde

1. **Certs** — de beheerder van moza-fsc-testnet tekent de csr's uit `pki/peers/moza/`; zie de
   callout hierboven.
2. **Bundle** — in moza-fsc-testnet: `pki/geheimen.sh ophalen moza` en `pki/zad-bundle.sh moza`
   → upload-klare cert-set in `pki/zad-upload/moza/` daar.
3. **Deployment `fsc-moza` éénmalig leeg aanmaken** (ZAD-UI of `zadctl`, project `mfp-z64`). De
   raw v2-API `:upsert-deployment` maakt géén NIEUWE deployment aan (geeft wel 202 maar het
   deployment verschijnt niet in `/deployments`); het UPDATET alleen een bestaand deployment.
4. **`upsert-peer.sh plan`** (dry-run, alleen `jq`, geen netwerk) — toont de deployment- + zes
   component-bodies zonder te muteren.
5. **`upsert-peer.sh validate`** (vereist `ZAD_API_KEY`) — read-only auth-check tegen de ZAD-API.
6. **`upsert-peer.sh apply`** (vereist `ZAD_API_KEY`, `ZAD_PG_PASSWORD`, `ZAD_CSRF_AUTH_KEY`) —
   upsert het deployment + de zes componenten, pollt de resulterende tasks.
7. **Bijlagen en publicatie** (zie `cert-manifest.md`) — cert-bijlagen, het Postgres-init-script,
   een persistent volume voor `moza-fscpg` en "Publicatie op het web" (passthrough-TLS op
   `moza-fscmgr` en `moza-fscinway`). Kan in de UI of via de v2-API; de calls staan in
   `cert-manifest.md`.
8. **`verify-zad.md`** — announce en de vervolgstappen.
9. **Gezondheidscontrole** — de eerste poort van manager, inway, outway en txlog is een
   TLS-luisteraar; de standaard-TCP-probe van ZAD laat daar elke twee seconden een
   `http: TLS handshake error ... EOF` achter. Zet de probe daarom op de `MONITORING_ADDRESS`-poort
   (`8080` voor de manager, `8081` voor de rest) en gebruik voor liveness nooit `/health/ready`
   (dan herstart een component dat alleen zijn txlog kwijt is).
10. **Beheertoegang** — de beheer-UI van `moza-fscctl` staat op de publieke ingress en laat met
    `AUTHN_TYPE=none` iedere bezoeker als beheerder binnen. Bind de ZAD-diensten `keycloak` +
    `authorization-wall` aan dit component vóórdat het een publicatie op het web krijgt.

## Lessen uit de berichtenbox-peers

Deze punten zijn overgenomen uit `moza-poc-fbs-berichtenbox` (zelfde v2-API, zelfde OpenFSC-images):

- **Component-env wordt alleen bij CREATIE toegepast** — runtime-env wijzig je met `zadctl env` of
  in de UI. Component niet verwijderen om env te wijzigen (kost de cert-attachments).
- **Geen `$DEPLOYMENT_NAME`-substitutie** — `upsert-peer.sh` lost alle inter-component-hostnamen
  concreet op in `env_vars`.
- **txlog is verplicht** voor een niet-directory-manager.
- **Cert-mount-valkuilen** — internal-pad = internal-cert; group-pad = group-cert **inclusief**
  intermediate. `TLS_GROUP_ROOT_CERT` = group-root; internal-`TLS_ROOT_CERT` = internal-CA-root.
- **Multi-poort** — interne FSC-edges lopen over de cluster-Service-DNS `<deployment>-<comp>:<poort>`
  (9443/9444, txlog 8443), niet over de `:443`-ingress; de internal-certs dragen die Service-DNS als
  SAN. Alleen de externe mesh (manager én inway `SELF_ADDRESS`) loopt op `:443` (SNI-passthrough).
- **NetworkPolicy** — ZAD isoleert deployments onderling, ook binnen één project. Een afnemende
  applicatie buiten `fsc-moza` bereikt de outway alleen via een publicatie op het web of een
  `cross-domain-access`-uitzondering (zie `verify-zad.md`).

## Env-vars

| Variabele | Default | Rol |
|-----------|---------|-----|
| `ZAD_API_KEY` | — (verplicht bij `validate`/`apply`) | Projecttoken voor `mfp-z64`. **Niet** inline zetten (`export`, niet `ZAD_API_KEY=... ./upsert-peer.sh ...` — dat komt in de shell-history). |
| `ZAD_PROJECT` | `mfp-z64` | ZAD-project. Bepaalt óók de namespace (`rig-prd-<project>`) in de cert-SAN's — `pki/gen-csr.sh` leest dezelfde var, dus een projectwissel vraagt om her-uitgeven + opnieuw uploaden van de certs. |
| `ZAD_DEPLOYMENT` | `fsc-moza` | Default voor het `[deployment]`-argument (het CLI-arg wint). Gedeeld met `pki/gen-csr.sh` zodat cert-SAN's en deploy-adressen sporen. |
| `ZAD_BASE` | `https://zad.rijksapp.nl` | Basis-URL van de ZAD v2 Operations Manager API. |
| `ZAD_BASE_DOMAIN` | `rig.prd1.gn2.quattro.rijksapps.nl` | Base-domain voor de per-component mesh-hostnamen. |
| `ZAD_MANAGER_TAG` / `ZAD_CONTROLLER_TAG` / `ZAD_TXLOG_TAG` | = het `tag`-argument | Losse tag-override per migrate-wrapper, los van de OpenFSC stock-tag voor outway en inway. |
| `ZAD_MANAGER_IMAGE` / `ZAD_CONTROLLER_IMAGE` / `ZAD_TXLOG_IMAGE` | `ghcr.io/minbzk/moza-fsc-testnet-{manager,controller,txlog}-migrate:<tag>` | Volledige image-override per wrapper. manager/controller/txlog draaien een wrapper (`migrate up && serve`, ZAD kent geen init-containers); outway en inway hebben geen DB en gebruiken het stock-image. |
| `ZAD_DIRECTORY_MANAGER_HOST` | `dirmgr-test-mft-tp9.<base-domain>` | Directory-manager van `moza-fsc-testnet` op ZAD. |
| `ZAD_PG_PASSWORD` | — (verplicht bij `apply`) | Wachtwoord voor `moza-fscpg`. **Niet** committen. Komt zowel in `POSTGRES_PASSWORD` als in de component-DSN's. |
| `ZAD_CSRF_AUTH_KEY` | — (verplicht bij `apply`) | Ondertekent het CSRF-token van de controller (`openssl rand -hex 16`). **Niet** committen. |
| `ZAD_PG_SSLMODE` | `disable` | SSL-mode voor de `moza-fscpg`-DSN (intra-cluster). |
| `ZAD_PG_USER` / `ZAD_PG_DB` | `fsc` / `fsc` | Rol resp. database van `moza-fscpg`. |
| `ZAD_MGR_SCHEMA` / `ZAD_TXLOG_SCHEMA` | `manager` / `txlog` | `search_path`-schema voor de migratie-teller van manager resp. txlog (isolatie). Moeten sporen met `postgres-init.sql`. |
| `ZAD_CTL_SCHEMA` | _(leeg)_ | De controller draait **zonder** search_path — die maakt z'n eigen `controller`-schema aan; mét search_path loopt migratie #1 dirty vast. |
| `ZAD_POSTGRES_IMAGE` | `docker.io/library/postgres:17` | Image voor `moza-fscpg`. |
| `ZAD_PEER_CLONE_FROM` | _(leeg)_ | Optionele `cloneFrom` op `:upsert-deployment`. Leeg = geen clone (aanbevolen). |

```bash
export ZAD_API_KEY=... ZAD_PG_PASSWORD=... ZAD_CSRF_AUTH_KEY=...
./deploy/zad/upsert-peer.sh plan
./deploy/zad/upsert-peer.sh validate
./deploy/zad/upsert-peer.sh apply
```
