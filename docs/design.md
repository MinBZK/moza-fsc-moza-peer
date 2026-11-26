**Status:** Concept

# Ontwerp — FSC-peer `moza`

> De FSC-peer van MOZa in de MOZa FSC-testfederatie van
> [`moza-fsc-testnet`](https://github.com/MinBZK/moza-fsc-testnet) (directory + group-CA).
> Gemodelleerd naar de peer `logius` in
> [`moza-poc-fbs-berichtenbox`](https://github.com/MinBZK/moza-poc-fbs-berichtenbox/tree/main/demo/environment/logius).

## Aanleiding

`moza-fsc-testnet` levert de generieke FSC-infra: de **directory** (group-anker) en de
group-config/CA. Elke deelnemer zet daarnaast een eigen peer neer. Deze repo bevat de peer van
MOZa zelf: een **bidirectionele** peer met een **outway** (diensten van andere peers afnemen) en
een **inway** (eigen diensten aanbieden). Bij oplevering is er nog geen gepubliceerde dienst en
geen afnemer-contract; die volgen zodra bekend is welke MOZa-diensten via FSC lopen.

Anders dan `logius` (co-located in het project van de `uitvraag`-app) staat deze peer in een
**eigen ZAD-project**. Daardoor speelt het clone-risico van PR-previews niet, en blijft de
peer-identiteit los van de levenscyclus van een applicatie.

> **Niet voor productie.** Test-PKI en test-federatie (`moza-fbs-test`). Sleutels/certs horen
> **niet** in git — zie `.gitignore`.

## Identiteit

| Parameter | Waarde |
|-----------|--------|
| Peer-naam (`subject.O`) | `MOZa` (identifier in paden/DNS/ZAD: `moza`) |
| Peer-OIN = Peer ID (`subject.serialNumber`) | `00000000000000002000` |
| Group ID | `moza-fbs-test` |
| Directory-OIN | `00000000000000000010` |
| Endpoints (PKI) | `manager`, `outway`, `inway`, `controller`, `txlog` |
| FSC-images (pin) | `v2.5.2` |
| ZAD-project | `MOZa FSC Peer` (technisch: `mfp-z64`) |
| ZAD-deployment | `fsc-moza` |
| ZAD-componenten | `moza-fscmgr`, `moza-fscoutway`, `moza-fscinway`, `moza-fscctl`, `moza-fsctxlog`, `moza-fscpg` |

**Peer ID = geldige OIN** (uit cert `subject.serialNumber`), peer-naam uit `subject.organization`.
De OIN staat in **lockstep** met `pki/gen-csr.sh` en elke `pki/peers/moza/<endpoint>/csr.json`.

## Wat dit wel/niet is

- **GEEN fork** van de FSC-software. Dit is een **deploy- en configuratie-repo** die
  [OpenFSC](https://gitlab.com/rinis-oss/fsc/open-fsc) (EUPL-1.2, RINIS) consumeert via haar
  container-images.
- **WEL**: test-PKI, peer-configuratie, lokale compose-proof, ZAD-deploy (`upsert-peer.sh` +
  workflow voor tag-updates), runbooks.
- **Migratie-wrappers:** ZAD ondersteunt geen init-containers → manager/controller/txlog draaien
  `ghcr.io/minbzk/moza-fsc-testnet-{manager,controller,txlog}-migrate` (`migrate up && serve`);
  outway en inway hebben geen DB en gebruiken het stock-image.

## Componenten

| Component | ZAD-ref | Rol |
|-----------|---------|-----|
| manager | `moza-fscmgr` | Announce bij de directory + contract-/token-uitgifte. Géén `AUTO_SIGN_GRANTS` (dat is directory-only). |
| outway | `moza-fscoutway` | Egress-proxy voor afnemende applicaties; registreert zich bij de controller (`:9443`) en praat met de manager op `:9443`. |
| inway | `moza-fscinway` | Ingress-proxy vóór aangeboden diensten; registreert zich bij de controller (`:9443`) en leest config bij de manager op `:9444`. Eigen `:443`-route (SNI-passthrough). De upstream is de `endpoint_url` bij service-publicatie. |
| controller | `moza-fscctl` | Beheer-UI + Administration/Registration-API (`AUTHN_TYPE=none`; op ZAD achter de `authorization-wall`). |
| txlog | `moza-fsctxlog` | Transaction-log API (internal-PKI mTLS). Verplicht voor een niet-directory-manager. |
| DB | `moza-fscpg` | Self-hosted Postgres; één DB, geïsoleerde migratie-tellers per component (`manager`/`txlog`-schema, controller zonder search_path). |

### Certificaat-topologie

Elk endpoint krijgt twee ketens:

- **GROUP** (getekend door de group-intermediate van fsc-testnet) → `TLS_GROUP_CERT/KEY` (+
  hergebruikt voor `TLS_GROUP_TOKEN_*` en `TLS_GROUP_CONTRACT_*`). De OIN staat in `serialnumber`.
- **INTERNAL** (per-peer self-signed CA) → `TLS_CERT/KEY` (+ `TLS_INTERNAL_UNAUTHENTICATED_*`),
  voor mTLS tussen manager ↔ controller ↔ outway ↔ inway ↔ txlog. Draagt de cluster-Service-DNS
  (`fsc-moza-moza-<comp>` + FQDN in `rig-prd-mfp-z64`) als SAN.

### Onboarding-flow

```text
moza                                   centrale kern (directory, moza-fsc-testnet)
  manager ───announce────────────────────►  directory-manager (:443)
  controller ──(beheer-UI)──────────────►  eigen manager (:9443)
  outway ──register + config──────────────►  eigen controller (:9443) + manager (:9443)
  inway ──register + config───────────────►  eigen controller (:9443) + manager (:9444)
```

1. **Cert** — group-cert voor OIN `00000000000000002000` (`pki/issue.sh`, met de group-CA van fsc-testnet).
2. **Deploy** — lokaal compose (`deploy/local/`), daarna ZAD (`deploy/zad/upsert-peer.sh`).
3. **Announce** — manager verschijnt in de directory met `manager_address` op `:443`.

## Levering

1. **Lokale compose-proof** (`deploy/local/`): directory + peer + SNI-router. Bewijst boot,
   announce, en publicatie/discovery van een stub-dienst `echo-service`.
2. **ZAD** (`deploy/zad/`): eenmalige creatie via `upsert-peer.sh`, cert-attachments en
   "Publicatie op het web" in de UI, tag-updates via `.github/workflows/deploy.yml`.

## Open punten

- **Group-CA** — de group-cert-set moet getekend worden met de CA van `moza-fsc-testnet`; die
  sleutels staan niet in deze repo.
- **Secrets** — `ZAD_API_KEY` (GitHub-secret + lokaal), `ZAD_PG_PASSWORD` en `ZAD_CSRF_AUTH_KEY`
  moeten er zijn vóór de eerste `apply`.
- **Diensten en contracten** — welke MOZa-diensten de inway aanbiedt en welke de outway afneemt.
- **Bereikbaarheid van de outway** — ZAD isoleert deployments; een afnemende applicatie in een
  ander project vraagt een publicatie op het web of een `cross-domain-access`-uitzondering.
- **OIN-registratie** — `00000000000000002000` is een test-OIN; controleer dat hij in de
  testfederatie niet al door een andere peer geclaimd wordt.
