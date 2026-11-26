# moza-fsc-moza-peer

FSC-peer voor alle MOZa-projecten: de peer `moza` (OIN `00000000000000002000`, organisatie `MOZa`)
in de MOZa FSC-testfederatie van [`moza-fsc-testnet`](https://github.com/MinBZK/moza-fsc-testnet).
De peer heeft een outway (diensten afnemen) en een inway (diensten aanbieden). Er zijn nog geen
diensten gepubliceerd en geen contracten afgesloten.

Opgezet naar het voorbeeld van de peer `logius` in
[`moza-poc-fbs-berichtenbox`](https://github.com/MinBZK/moza-poc-fbs-berichtenbox/tree/main/demo/environment/logius).
Zie [`docs/design.md`](docs/design.md) voor het ontwerp.

> **Niet voor productie.** Test-PKI en test-federatie. Sleutels/certs horen niet in git.

## Indeling

| Map | Inhoud |
|-----|--------|
| `pki/` | Test-PKI: CSR's per endpoint, uitgifte, verificatie, ZAD-uploadbundel. |
| `deploy/local/` | Lokale compose-harness: directory + peer + SNI-router, met smokes. |
| `deploy/zad/` | ZAD-deploy (`upsert-peer.sh`) en runbooks voor certs en verificatie. |
| `lib/` | Harness-helpers, overgenomen uit moza-poc-fbs-berichtenbox. |
| `.github/workflows/deploy.yml` | Image-tag-updates op ZAD (handmatig te starten). |

## Lokaal draaien

Vereist `cfssl`, `jq` en Docker of podman met `docker compose` v2.

```bash
cd pki && ./init-ca.sh && ./issue.sh && ./gen-crl.sh && ./verify.sh && cd -
cp deploy/local/.env.example deploy/local/.env
printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)" >> deploy/local/.env
./deploy/local/up.sh           # kiest docker, bridge of hostnet; zie deploy/local/README.md
./deploy/local/run-smokes.sh   # verwacht: "ALLE SMOKES GROEN."
./deploy/local/up.sh down -v
```

De directory-UI staat op `http://127.0.0.1:8081`, de controller-UI op `:8091`.

## ZAD

| | |
|---|---|
| Project | `MOZa FSC Peer` (technische naam `mfp-z64`) |
| Deployment | `fsc-moza` |
| Componenten | `moza-fscmgr`, `moza-fscctl`, `moza-fscoutway`, `moza-fscinway`, `moza-fsctxlog`, `moza-fscpg` |

De eerste creatie van de componenten (env, poorten, certs) is een eenmalige handmatige stap: zie
[`deploy/zad/README.md`](deploy/zad/README.md), [`cert-manifest.md`](deploy/zad/cert-manifest.md) en
[`verify-zad.md`](deploy/zad/verify-zad.md). Daarna werkt de workflow alleen de image-tags bij; die
vraagt het repository-secret `ZAD_API_KEY` (een token van project `mfp-z64`).

## Licentie

De FSC-software zelf komt uit [OpenFSC](https://gitlab.com/rinis-oss/fsc/open-fsc) (EUPL-1.2) en
wordt alleen als container-image gebruikt.
