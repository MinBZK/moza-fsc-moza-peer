# lib/ — gedeelde harness-helpers

Overgenomen uit [`MinBZK/moza-poc-fbs-berichtenbox`](https://github.com/MinBZK/moza-poc-fbs-berichtenbox)
(commit `8bdea83`), waar ze door meerdere peers gedeeld worden:

| Bestand | Bron | Rol |
|---------|------|-----|
| `peer-stack.sh` | `demo/environment/lib/peer-stack.sh` | Start/stop van de lokale harness (`deploy/local/up.sh`); paden aangepast aan deze repo, federatie-modus verwijderd. |
| `fsc-harness.sh` | `demo/environment/lib/fsc-harness.sh` | Helpers voor de smokes en `publish-service.sh`. |
| `podman-modus.sh` | `demo/lib/podman-modus.sh` | Keuze tussen docker, podman-bridge en podman-hostnet. |

Commentaar dat naar de federatie-opstelling of naar `magazijn-a` verwijst, slaat op de bronrepo.
Verbeteringen bij voorkeur ook upstream terugbrengen.
