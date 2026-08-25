; ============================================================
; Script Inno Setup — MaliPneus
; ============================================================
; À compiler avec Inno Setup (https://jrsoftware.org/isinfo.php)
; sur une machine Windows, après avoir généré le build Flutter
; (voir installer/PROCEDURE_BUILD.md pour les étapes complètes).
;
; Ouvrir ce fichier dans Inno Setup Compiler, puis Build > Compile
; (ou F9), produit dist\MaliPneus_Setup.exe
; ============================================================

#define MyAppName "MaliPneus"
#define MyAppShortName "MaliPneus"
#define MyAppVersion "3.0.0"
#define MyAppPublisher "MALI_CODE CENTER"
#define MyAppExeName "mali_pneus.exe"
; Chemin vers le dossier généré par `flutter build windows`, relatif
; à ce fichier .iss. À ajuster si l'emplacement diffère chez vous.
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Identifiant unique généré une seule fois pour cette application —
; NE JAMAIS CHANGER entre les versions, sinon Windows considère
; chaque mise à jour comme une application différente.
;
; Regénéré le 22/08/2026 : l'ancien AppId de ce fichier était celui
; hérité du clonage depuis MaliStock (gestion_commerciale), ce qui
; faisait que Windows traitait MaliPneus et MaliStock comme LA MÊME
; application (même clé de registre d'installation) — cause du
; conflit rencontré à l'installation. Ce nouveau GUID est propre à
; MaliPneus et ne doit plus jamais être changé à partir de maintenant.
AppId={{CCC32B06-3E8E-4D05-B29C-D990F805C408}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppShortName}
DefaultGroupName={#MyAppShortName}
; Affiche explicitement la page "Choisir le dossier de destination"
; pendant l'installation (comportement standard des logiciels
; professionnels) — l'utilisateur peut cliquer sur "Parcourir..." et
; choisir un autre dossier que celui proposé par défaut.
DisableDirPage=no
; Dossier de sortie du Setup.exe généré.
OutputDir=..\dist
OutputBaseFilename={#MyAppShortName}_Setup
Compression=lzma2/max
SolidCompression=yes
; Setup.exe lui-même nécessite des droits admin (installation dans
; Program Files), mais l'application une fois installée tourne en
; utilisateur standard — voir [Run] et la note sur les données.
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Icône affichée dans le panneau Programmes et fonctionnalités.
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern
SetupIconFile=app_icon.ico
DisableProgramGroupPage=yes
LicenseFile=LICENSE.txt

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
; Cases à cocher proposées pendant l'installation. La case "Lancer
; au démarrage de Windows" est optionnelle et décochée par défaut —
; un commerçant lance lui-même son logiciel, pas besoin de forcer.
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"; Flags: checkedonce
Name: "startupicon"; Description: "Lancer {#MyAppShortName} au démarrage de Windows"; GroupDescription: "Options :"; Flags: unchecked

[Files]
; Copie tout le contenu du build Release Flutter (exe + DLL +
; data\flutter_assets) — Source avec \*, pas juste le .exe seul,
; car Flutter Windows a besoin de ses DLL et assets pour fonctionner.
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Menu Démarrer (toujours créé).
Name: "{group}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Désinstaller {#MyAppShortName}"; Filename: "{uninstallexe}"
; Bureau (seulement si la case correspondante est cochée).
Name: "{autodesktop}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; Démarrage automatique de Windows (optionnel, décoché par défaut).
; {commonstartup} (et non {userstartup}) car PrivilegesRequired=admin :
; l'installateur tourne dans le contexte admin, {userstartup} pointerait
; alors vers le mauvais dossier utilisateur.
Name: "{commonstartup}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
; Propose de lancer l'application immédiatement après l'installation.
Filename: "{app}\{#MyAppExeName}"; Description: "Lancer {#MyAppShortName} maintenant"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; IMPORTANT : on NE supprime PAS le dossier de données utilisateur
; (Documents\MaliPneus, contenant la base SQLite, les PDF
; et les sauvegardes) à la désinstallation. Cette section ne
; nettoie que des fichiers temporaires éventuels dans {app}, jamais
; les données métier du commerçant. Voir la note "DONNÉES" en bas
; de ce fichier pour le détail de cette décision.
Type: filesandordirs; Name: "{app}\data\flutter_assets\.last_build_id"

[Code]
{ Vérifie au lancement de l'installateur si une version est déjà
  installée, pour informer l'utilisateur qu'il s'agit d'une mise à
  jour (les données existantes ne sont jamais touchées par Setup,
  uniquement les fichiers programme dans Program Files). }
function InitializeSetup(): Boolean;
begin
  Result := True;
end;

{ ============================================================
  NOTE IMPORTANTE SUR LES DONNÉES (à lire avant toute modification
  de ce script) :

  L'application stocke toutes les données du commerçant (base
  SQLite, PDF générés, logo, sauvegardes) dans :
    C:\Users\<utilisateur>\Documents\MaliPneus\

  Ce dossier est CRÉÉ ET GÉRÉ PAR L'APPLICATION ELLE-MÊME au premier
  lancement (voir lib/data/local/database.dart côté code source),
  PAS par cet installateur. Conséquences :

  - Désinstaller puis réinstaller l'application NE SUPPRIME JAMAIS
    les données du commerçant, puisque Setup ne touche qu'au dossier
    Program Files, jamais à Documents.
  - Une mise à jour future (nouvelle version de l'exe) n'écrasera
    jamais la base de données existante.
  - Pour un vrai nettoyage complet (rare, demandé explicitement par
    le commerçant), il faudrait supprimer ce dossier manuellement —
    ce script ne le fait jamais automatiquement, par sécurité.
  ============================================================ }

{ ============================================================
  NOTE SUR LE CHANGEMENT D'AppId (22/08/2026) :

  Si une version antérieure de MaliPneus a déjà été installée avec
  CE script AVANT ce changement (donc avec l'ancien AppId hérité de
  MaliStock), ce nouveau Setup.exe ne la détectera PAS comme une
  mise à jour — Windows les traite comme deux applications
  différentes. Désinstaller manuellement toute installation
  MaliPneus antérieure (Panneau de configuration > Programmes) avant
  d'installer cette version, pour éviter deux entrées séparées dans
  la liste des programmes installés.

  Ceci ne se reproduira plus pour les prochaines mises à jour : à
  partir de maintenant, l'AppId reste fixe.
  ============================================================ }
