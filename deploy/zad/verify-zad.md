# Verificatie ná apply — moza-peer op ZAD

> Draaiboek: wat de operator ná een geslaagde `upsert-peer.sh apply` + cert-attachments (zie
> `cert-manifest.md`) nog controleert.

## Volgorde

1. `upsert-peer.sh apply` gedraaid → deployment `fsc-moza` + componenten bestaan in het ZAD-project
   `mfp-z64` (MOZa FSC Peer), elk met zijn `ports`-array (moza-fscmgr `8443,9443,9444`; moza-fscctl
   `8080,9443,9444`; moza-fscoutway/moza-fsctxlog `8443`; moza-fscinway `8443`) zodat de
   interne mTLS-poorten een cluster-Service (`fsc-moza-moza-<comp>:<poort>`) krijgen.
2. Cert-attachments gemount (zie `cert-manifest.md`) + "Publicatie op het web"
   (passthrough-TLS, modus 2) op moza-fscmgr **en** moza-fscinway ingesteld in de ZAD-UI. De
   outway moza-fscoutway is egress-only richting de mesh; zijn serve-poort `8443` is de ingang
   waarop een afnemende applicatie hem aanroept. Die poort draait TLS met het interne cert
   (`LISTEN_HTTPS=true`).

   **Let op: `upsert-peer.sh` zet env niet op een bestaande component.** ZAD past `env_vars` uit
   een component-body alleen toe bij component-*creatie*. Wijzig env op een bestaande component met
   `zadctl env` of in de UI, en controleer bij de outway de boot-log op `starting HTTPS server`.

   **NetworkPolicy.** ZAD isoleert deployments onderling, ook binnen één project; een applicatie in
   een ánder project of andere deployment bereikt de outway dus niet op zijn ClusterIP-Service.
   Óf de outway krijgt een publicatie op het web (`tls: standard` op `8443`), óf er komt een
   gerichte uitzondering via de platform-dienst `cross-domain-access`. Kies dat zodra de eerste
   afnemende applicatie bekend is.
3. Componenten herstart en boot-logs foutloos (zie `cert-manifest.md`, laatste sectie) — in het
   bijzonder GEEN `x509: certificate signed by unknown authority` op de controller: die
   bereikt de manager intern op `fsc-moza-moza-fscmgr:9443` (interne-PKI), niet via de `:443`-group-ingress.

## (a0) moza-fscinway (inway) — draait en registreert zich

- **Pod draait** — geen restart-loop op de moza-fscinway-component in de ZAD-UI.
- **Geen cert-ketenfout in de boot-log** — met name geen `certificate signed by unknown authority`
  (verkeerde group/internal-cert verwisseld, zie `cert-manifest.md`) en geen handshake-fout tegen
  `fsc-moza-moza-fscctl:9443` of `fsc-moza-moza-fscmgr:9444`.
- **Registratie bij moza-fscctl zichtbaar** — de controller-UI (of de Registration-API) toont de inway
  als geregistreerde inway voor deze peer. Zet de UI achter de `authorization-wall` (zie
  `README.md`, stap "Beheertoegang") en doe dit in een browser waarin je bent ingelogd.

## (a) Announce — OIN vindbaar in de directory

Verwacht gedrag (analoog aan `deploy/local/smoke-announce.sh`, maar tegen de ZAD-directory):

```bash
# Met de group-cert van moza/manager als client-cert:
curl -sS --cert <group-cert> --key <group-key> --cacert <group-root> \
  "https://<dirmgr-host-op-ZAD>/v1/peers" | jq '.[] | select(.id == "00000000000000002000")'
```

Verwacht: één entry met `id: "00000000000000002000"` en een `manager_address` die eindigt op
`:443` en het moza-fscmgr-hostpatroon (`moza-fscmgr-fsc-moza-mfp-z64.<base-domain>`) bevat.

Alternatief (UI): log in op de directory-UI van `moza-fsc-testnet` en zoek de peer op OIN.

## (b) Vervolg — diensten en contracten

Nog niet ingericht; dit volgt zodra bekend is welke diensten MOZa via FSC aanbiedt of afneemt.

**Aanbieden (inway):**

1. `CreateService` via de `moza-fscctl` Administration-API (`:9444`) met als `endpoint_url` de
   echte upstream en als inway-adres `https://moza-fscinway-fsc-moza-mfp-z64.<base-domain>:443`
   (lokaal voorbeeld: `deploy/local/publish-service.sh`).
2. De servicePublication wordt door de directory automatisch getekend; controleer met de
   discover-call (lokaal voorbeeld: `deploy/local/smoke-discover.sh`).

**Afnemen (outway):**

1. Een `serviceConnection`-contract met de aanbiedende peer, getekend door beide kanten (via de
   controller-UI of de manager-API).
2. De afnemende applicatie roept de outway aan met de header `Fsc-Grant-Hash` en vertrouwt
   `internal/moza/ca/root.pem` als CA voor de outway-poort.

## Acceptatie

- [ ] Alle zes componenten `Running`, geen restart-loop
- [ ] Geen x509-fouten in de boot-logs
- [ ] Announce: OIN `00000000000000002000` in de directory met `manager_address` op `:443`
- [ ] Inway geregistreerd bij moza-fscctl
- [ ] Controller-UI achter de `authorization-wall`
