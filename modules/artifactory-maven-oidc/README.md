# Maven-Repositories mit Keycloak-OIDC

Dieses Terraform-Modul erweitert die bestehende Artifactory-Installation um
ein lokales Maven-Repository und ein virtuelles Maven-Repository. Zusätzlich
kann es einen Keycloak-Demo-Provider in Kubernetes bereitstellen und eine
OIDC-Integration in JFrog konfigurieren.

## Use Case: Maven-Repositories ohne OIDC testen

**Ziel:** Prüfen, ob die vorhandene Artifactory-Instanz mit dem
Terraform-JFrog-Provider verwaltet werden kann, ohne Keycloak bereitzustellen
oder OIDC zu konfigurieren. Das funktioniert nur mit einer Artifactory-Edition,
deren Lizenz die Repository-REST-API freischaltet (zum Beispiel Pro). Für
Artifactory OSS bleibt der JFrog-Teil deaktiviert. Für diesen Test muss in
Keycloak nichts registriert werden.

Im Root-Modul ist der JFrog-Ressourcenteil mit `enable_jfrog_provider`
standardmäßig ausgeschaltet. Für den Pro-Test schalten Sie ihn über die
Umgebung ein; im Child-Modul bleiben OIDC und Keycloak ausgeschaltet:

```hcl
module "maven_oidc" {
  count  = var.enable_jfrog_provider ? 1 : 0
  source = "./modules/artifactory-maven-oidc"

  oidc_issuer_url = "https://keycloak.example.com/realms/demo"
  enable_oidc     = false
  deploy_keycloak = false
}
```

Die Issuer-URL bleibt als erforderliche Modulvariable gesetzt, wird bei
`enable_oidc = false` aber nicht für eine OIDC-Ressource verwendet. Der
`enable_jfrog_provider`-Schalter im Root-Modul ist ein Opt-in und steht
standardmäßig auf `false`; er ist kein Eingabewert des Child-Moduls. Wird er
aktiviert, verlangt Terraform einen nicht leeren JFrog-Admin-Token. Geben Sie
ihn nur in einer Umgebung mit aktivierter Pro-Lizenz an:

```sh
export TF_VAR_jfrog_admin_token='<JFrog-Admin-Token>'
export TF_VAR_enable_jfrog_provider=true
terraform init
terraform plan
terraform apply
```

Wenn `TF_VAR_enable_jfrog_provider` nicht gesetzt ist oder `false` lautet,
wird das Modul nicht instanziiert und es werden keine JFrog- oder Keycloak-
Ressourcen daraus geplant. Ist der Schalter `true`, aber
`TF_VAR_jfrog_admin_token` fehlt oder ist leer, bricht Terraform mit einer
Validierungsfehlermeldung ab. Damit kann der restliche Kubernetes-/Helm-Stack
ohne JFrog-Token weiter verwaltet werden.

Mit Pro prüfen Sie im Plan, dass `maven-local` und `maven-virtual` angelegt
werden und keine Keycloak- oder OIDC-Ressourcen geplant sind. Nach
erfolgreichem Apply sollten beide Repositories in der Artifactory-Oberfläche
sichtbar sein; das virtuelle Repository sollte `maven-local` enthalten. Damit
wird die Repository-Verwaltung mit Terraform geprüft, nicht die
Maven-Veröffentlichung oder OIDC-Anmeldung.

### Ergebnis und Einordnung

**Ergebnis mit Artifactory OSS:** Der Test schlägt fehl. `terraform apply`
bricht bei `artifactory_local_maven_repository` mit der Meldung
"This REST API is available only in Artifactory Pro" ab. Der Test funktioniert
nur mit Pro, etwa mit einer Testlizenz.

**Gründe:**

- Der Terraform-Provider `jfrog/artifactory` ist ein reiner Client der
  Artifactory-REST-API. Jede Ressource ruft einen API-Endpunkt auf, der Provider
  hat keinen eigenen Zugriff auf die Konfiguration oder Datenbank.
- In OSS ist die Repository-Konfigurations-API (Anlegen und Ändern von
  Repositories) gesperrt. Sie ist Pro-Funktionalität, deshalb lehnt der Server
  den Aufruf ab, bevor Terraform etwas anlegen kann.
- Der Fehler liegt weder an der Terraform-Konfiguration noch am Admin-Token.
  Der Token ist gültig, sonst käme eine Authentifizierungsfehlermeldung.
- Die OIDC-Ressourcen des Providers `jfrog/platform` setzen ebenfalls eine
  Edition mit OIDC-Unterstützung voraus. Sie wären der nächste Fehlerpunkt.

**Gibt es einen Terraform-Provider-Use-Case ohne REST-API?** Nein. Ohne die
verfügbare REST-API kann der JFrog-Provider keine Repositories, Berechtigungen
oder OIDC-Einstellungen verwalten. Das Root-Modul instanziiert deshalb die
JFrog-Ressourcen standardmäßig nicht (`enable_jfrog_provider = false`). Die
Provider sind weiterhin in der Terraform-Konfiguration deklariert und können
bei `terraform init` installiert werden; ohne Modulinstanz verwaltet Terraform
aber keine JFrog-Ressourcen. Mit OSS bleiben folgende Wege:

- Repositories manuell in der Weboberfläche anlegen.
- Das Deployment selbst (Namespace, Helm-Release, Secrets, Services) weiter mit
  Terraform über die `kubernetes`- und `helm`-Provider verwalten. Das war schon
  vor diesem Modul der Fall und benötigt keine Artifactory-API.
- Für Terraform-gesteuerte Repositories und OIDC auf eine Pro-Edition
  (zum Beispiel mit Testlizenz) wechseln.

Der Modulaufruf bleibt daher nur mit Pro sinnvoll.

## Ablauf

1. Terraform legt `maven-local` als lokales Maven-Repository an. Es akzeptiert
   Release- und Snapshot-Artefakte.
2. Terraform legt `maven-virtual` als virtuelles Maven-Repository an und nimmt
   `maven-local` darin auf. Clients können damit einen gemeinsamen Maven-Endpunkt
   verwenden.
3. Ist `deploy_keycloak = true`, legt Terraform den Namespace `keycloak`, eine
   Keycloak-Deployment und einen NodePort-Service an. Keycloak startet im
   Entwicklungsmodus und importiert den Realm `demo` mit dem OIDC-Client
   `maven-ci`. Der Service ist im Cluster auf Port 8080 und über NodePort 30090
   erreichbar.
4. Ist `enable_oidc = true`, legt Terraform in JFrog einen generischen
   OIDC-Provider und ein Identity-Mapping an. Das Mapping akzeptiert Tokens,
   deren `azp`-Claim dem konfigurierten Client entspricht, und stellt sie in
   JFrog als Benutzer `maven-ci` mit dem Scope `applied-permissions/user` aus.
   Eine Permission gewährt diesem Benutzer `read`, `write` und `annotate` auf
   `maven-local`.

## Wichtige Voraussetzungen und Einschränkungen

- **Dieses Modul benötigt Artifactory Pro oder höher.** Die REST-API zum
  Anlegen von Repositories ist in Artifactory OSS nicht verfügbar. Der
  Terraform-Lauf bricht dort bereits bei `artifactory_local_maven_repository`
  mit der Meldung "This REST API is available only in Artifactory Pro" ab.
  Auch die OIDC-Integration benötigt eine JFrog-Edition, die OIDC unterstützt.
  In OSS legen Sie Repositories deshalb manuell in der Weboberfläche an.
- `enable_oidc = false` überspringt nur die OIDC- und Permission-Ressourcen,
  `deploy_keycloak = false` den Keycloak-Demo. Beides macht das Modul nicht
  OSS-tauglich, da die Repository-Ressourcen weiterhin angelegt werden.
- Keycloak läuft mit `start-dev` und wird hier ohne TLS-Ingress eingerichtet.
  Für eine echte OIDC-Integration muss der Issuer von Artifactory über HTTPS
  erreichbar sein. Die konfigurierte Issuer-URL muss exakt mit dem `iss`-Claim
  in den Keycloak-Tokens übereinstimmen. Richten Sie daher einen HTTPS-Endpunkt
  (beispielsweise per Ingress/Reverse-Proxy) ein und setzen Sie
  `oidc_issuer_url` auf `https://<host>/realms/demo`.
- Die Beispielwerte für das Keycloak-Admin-Passwort und das Client-Secret sind
  **nicht für den Produktivbetrieb geeignet**. Überschreiben Sie sie mit
  sicheren Werten und speichern Sie diese nicht im Repository.
- OIDC ersetzt nicht die Authentifizierung von Terraform gegenüber der JFrog
  API. Terraform benötigt für das Erstellen der Repositories und der
  OIDC-Konfiguration weiterhin einen JFrog-Admin-Token. Maven-/CI-Clients
  verwenden anschließend OIDC statt eines dauerhaft gespeicherten
  Artifactory-Access-Tokens.
- Das Modul verwendet die Provider `jfrog/artifactory`, `jfrog/platform` und
  `hashicorp/kubernetes` aus der Root-Konfiguration. Es ist daher für die
  Einbindung in dieses Repository vorgesehen.

## Konfiguration im Root-Modul

Die Root-Konfiguration bindet dieses Modul als `maven_oidc` ein. Vor dem
Terraform-Lauf:

1. Setzen Sie `jfrog_url` auf die URL, unter der Terraform Artifactory erreicht.
   Der Standardwert in `main.tf` ist `http://localhost:30080`.
2. Setzen Sie `oidc_issuer_url` im Modul-Aufruf auf die öffentliche HTTPS-URL
   Ihres Keycloak-Realms. Der aktuelle Wert
   `https://keycloak.example.com/realms/demo` ist ein Platzhalter und muss
   ersetzt werden.
3. Aktivieren Sie den JFrog-Provider explizit und übergeben Sie den
   JFrog-Admin-Token als Umgebungsvariable, nicht als Klartext im Code. Das ist
   nur mit einer passenden Artifactory-Lizenz sinnvoll:

   ```sh
   export TF_VAR_enable_jfrog_provider=true
   export TF_VAR_jfrog_admin_token='<JFrog-Admin-Token>'
   terraform init
   terraform plan
   terraform apply
   ```

   Ohne `TF_VAR_enable_jfrog_provider=true` bleibt das JFrog-Modul aus. Wird
   es aktiviert, aber der Token nicht gesetzt, schlägt die Eingabevalidierung
   fehl.

4. Ersetzen Sie die Keycloak-Demo-Zugangsdaten. Modulvariablen werden nicht
   automatisch als Root-Variablen verfügbar. Deklarieren Sie daher bei Bedarf
   sensible Root-Variablen in `main.tf`, übergeben Sie diese an das Modul und
   setzen Sie die Root-Variablen über die Umgebung:

   ```sh
   export TF_VAR_keycloak_admin_password='<sicheres-Admin-Passwort>'
   export TF_VAR_oidc_client_secret='<sicheres-Client-Secret>'
   ```

   Dazu gehören beispielsweise folgende Deklarationen und Modulargumente:

   ```hcl
   variable "keycloak_admin_password" {
     type      = string
     sensitive = true
   }

   variable "oidc_client_secret" {
     type      = string
     sensitive = true
   }

   module "maven_oidc" {
     # Bestehende Argumente beibehalten
     keycloak_admin_password = var.keycloak_admin_password
     oidc_client_secret      = var.oidc_client_secret
   }
   ```

   Ergänzen Sie die Argumente im bestehenden `module "maven_oidc"`-Block;
   definieren Sie keinen zweiten Block mit demselben Namen. Änderungen an den
   Demo-Standardwerten des Moduls sollten nicht als Ersatz für sichere
   Zugangsdaten verwendet werden.

Führen Sie `terraform plan` aus und prüfen Sie insbesondere die Provider-URLs,
die Issuer-URL sowie die geplanten JFrog-Ressourcen, bevor Sie `apply` ausführen.

## Modulvariablen

| Variable | Standard | Zweck |
| --- | --- | --- |
| `local_repo_key` | `maven-local` | Schlüssel des lokalen Maven-Repositories |
| `virtual_repo_key` | `maven-virtual` | Schlüssel des virtuellen Maven-Repositories |
| `enable_oidc` | `true` | OIDC-, Identity-Mapping- und Permission-Ressourcen anlegen |
| `oidc_issuer_url` | erforderlich | HTTPS-Issuer-URL des Keycloak-Realms |
| `oidc_audience` | `jfrog-artifactory` | Audience, die Keycloak in das Token aufnimmt |
| `oidc_client_id` | `maven-ci` | Keycloak-Client-ID und erwarteter `azp`-Claim |
| `oidc_client_secret` | Demo-Secret | Secret des vertraulichen Keycloak-Clients |
| `deploy_keycloak` | `true` | Keycloak-Demo in Kubernetes bereitstellen |
| `keycloak_namespace` | `keycloak` | Kubernetes-Namespace für Keycloak |
| `keycloak_admin_password` | `admin` | Keycloak-Bootstrap-Admin-Passwort |

Die Outputs `local_repo`, `virtual_repo`, `oidc_issuer_url` und
`oidc_token_endpoint` geben die Repository-Schlüssel und OIDC-Endpunkte aus.