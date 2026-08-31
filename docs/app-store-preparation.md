# MacPad App Store Preparation

**Audit date:** 2026-08-31

**Scope:** MacPad desktop only

**Status:** Repository-local preparation; not a release record

This document is the authoritative repository source for MacPad App Store
metadata drafts, privacy evidence, public-page copy, review instructions,
identifier proposals, and unresolved owner gates. It implements preparation
work only.

| State | Current evidence |
| --- | --- |
| Repository-local preparation implemented | Yes: this document and the qualified README link |
| Launch model | Owner-approved free, privately maintained, non-commercial hobby release with no ads, subscriptions, in-app purchases, donations, paid support, or paid bundle |
| Apple Developer Program | Active membership is required for App Store distribution; repository evidence cannot establish it, and the owner treats the fee as a hobby expense |
| Credential-free build and test evidence | Must be recorded for the exact candidate; it does not establish signing or distribution |
| Merged | No: implementation branch only; merge not performed |
| Production-signed or notarized | No |
| Submitted to App Store Connect | No |
| Approved by App Review | No |
| Distributed through the Mac App Store | No |
| Verified live with a customer account | No |

No Apple account, certificate, team, signing, notarization, upload, live
free-price or storefront entry, publication, DNS, SourceForge, or
repository-visibility action is authorized by this document.

## Source and privacy audit

The statements below describe the source at the audit date. They must be
checked again against the final candidate rather than copied forward as
permanent assumptions.

| Area | Repository evidence | Finding |
| --- | --- | --- |
| Dependencies | Package.swift | The package declares only the local NotepadMacCore and NotepadMac targets and their tests. It declares no external package dependency. |
| Imports | Sources | AppKit, Foundation, CryptoKit, Darwin, OSLog, UniformTypeIdentifiers, and the local NotepadMacCore module are used. No third-party module is imported. |
| Customer links | Sources/NotepadMac/DistributionChannel.swift and Sources/NotepadMac/AppDelegate.swift | Both channels compile only the approved product, support, and privacy destinations on macpad.net for About. Help and Support also use the support page. Creator, source-code, visible email, and mailto presentation are absent. The Direct channel retains only its separate temporary GitHub update route. NSWorkspace opens a configured web route in the user's default browser; MacPad does not implement a web view or network client. |
| Preferences | Sources/NotepadMac/AppDelegate.swift and Sources/NotepadMac/EditorFontPreferences.swift | Active repository-managed keys are MacPad.ShowInMenuBar, MacPad.RecentDocumentBookmarks.v1, and MacPad.EditorFont.v1. On launch, MacPad deletes the obsolete MacPad.SessionState.v1 value without clearing or changing recent-document bookmarks. |
| Launch and recent documents | Sources/NotepadMac/AppDelegate.swift and Sources/NotepadMac/RecentDocumentStore.swift | A normal launch opens exactly one new blank document and does not write or restore document-session state. Saved files remain available through Open Recent. Explicit file opens and app-scoped bookmarks remain separate from the removed session behavior. |
| File access | Sources/NotepadMacCore/EditorDocument.swift and Sources/NotepadMac/SecurityScopedFileAccess.swift | MacPad reads and writes user-selected files, coordinates writes, writes atomically, and uses app-scoped security bookmarks for persistent Store access. |
| Hashing | Sources/NotepadMacCore/EditorDocument.swift | CryptoKit SHA-256 is used locally to compare file content and detect an external change. It is not a network or user-facing encryption feature. |
| Diagnostics | Sources/NotepadMac/AppDelegate.swift | OSLog records local preference and recent-document errors. MacPad contains no remote logging or crash-reporting SDK. A local diagnostic message can contain a local file path. |
| Absent integrations | Package.swift and Sources | No URLSession, WebKit, Network, CloudKit, StoreKit, analytics, advertising, account, telemetry, or third-party SDK is present. |

### Local content is not collected data

MacPad processes document content on the Mac. It does not send document
content, preferences, bookmarks, recent-file information, diagnostics, or
usage data to the developer or a third party. Apple defines collection for
App Privacy as transmitting data off the device in a form retained beyond
the time needed to service a real-time request. Apple also states that data
processed only on the device is not collected for the App Privacy answers.

Opening a configured Help, Support, Privacy, or Security route leaves MacPad
and opens the destination in the default browser. The public website must describe its own processing
separately. The compiled macpad.net destinations remain a hard release gate
until Shared Services verifies that the correct anonymous MacPad pages are
live in English and German.

Draft App Privacy answer: **No data collected.** The owner must enter and
attest that answer in App Store Connect only after a final-source,
final-dependency, and final-archive audit.

## Privacy-manifest decision

Do not add PrivacyInfo.xcprivacy for the current source.

The decision is based on all of the following:

- the current package has no third-party SDK;
- the current app sends no data off device;
- Apple's current required-reason API article names iOS, iPadOS, tvOS,
  visionOS, and watchOS, not macOS; and
- Apple does not require an empty manifest merely because the target is a
  macOS app.

This is not a permanent exemption. Re-audit before release and whenever a
dependency or SDK is added, networking or telemetry is introduced, account
or advertising behavior changes, Apple changes its requirements, Xcode's
privacy report changes, or the final archive differs from the audited
source. If a manifest later becomes necessary, Apple specifies
Contents/Resources/PrivacyInfo.xcprivacy for a macOS app and rejects invalid
manifest files.

## English App Store draft

### App name

MacPad

Length: 6 characters.

### Subtitle

Plain text, instantly

Length: 21 characters.

### Promotional text

Open a clean text window from the menu bar, then edit, find, save, and print
without project clutter. Native, bilingual, and built for plain text.

Length: 146 characters and 146 UTF-8 bytes.

### Description

Plain text. Instantly.

MacPad is a fast, native plain-text editor for macOS. Turn on the optional
menu-bar launcher and a new empty window is one click away.

Write and edit with native windows and tabs. Find and replace, adjust the
font and zoom, show line and column status, print, and reopen recent
documents.

MacPad detects and preserves UTF-8, UTF-8 BOM, UTF-16 LE/BE, Windows-1252,
and ISO-8859-1. It preserves Windows, Unix, classic Mac, and mixed line
endings. If another app changes an open file, MacPad warns before
overwriting it and offers safe next steps.

Each normal launch opens one new blank document. Saved documents do not
reopen automatically and remain available through Open Recent. MacPad is
free and developed as a private, non-commercial hobby project. It has no
account, ads, subscriptions, in-app purchases, donations, analytics, or
cloud sync. Document contents stay on your Mac and are never transmitted by
MacPad.

Requires macOS 14 or later. English and German included.

### Keywords

plain text,editor,notes,writing,utf-8,encoding,tabs,menu bar,offline,line endings

Length: 81 UTF-8 bytes.

### Release notes draft

First Mac App Store release. MacPad provides fast native plain-text editing,
optional menu-bar access, English and German, tabs, encoding and line-ending
preservation, safe external-change handling, and Open Recent access to saved
documents.

This is launch release copy for the future approved website, review package,
or release history. It is not an App Store Connect What's New field. Apple
says What's New is unavailable for an app's first Store version and required
for later versions.

### Screenshot captions

1. New plain text from the menu bar
2. Native tabs, search, and clear status
3. Protection when a file changes elsewhere

## German App Store draft

### App-Name

MacPad

Länge: 6 Zeichen.

### Untertitel

Klartext, sofort

Länge: 16 Zeichen.

### Werbetext

Öffne ein leeres Textfenster direkt über die Menüleiste. Bearbeite, suche,
sichere und drucke ohne Projektballast – nativ und zweisprachig.

Länge: 139 Zeichen und 144 UTF-8-Bytes.

### Beschreibung

Klartext. Sofort.

MacPad ist ein schneller, nativer Klartext-Editor für macOS. Aktiviere
optional das Menüleisten-Symbol, und ein leeres Fenster ist nur einen Klick
entfernt.

Schreibe und bearbeite Text in nativen Fenstern und Tabs. Suche und ersetze,
passe Schrift und Zoom an, zeige Zeile und Spalte an, drucke und öffne
zuletzt verwendete Dokumente erneut.

MacPad erkennt und erhält UTF-8, UTF-8 BOM, UTF-16 LE/BE, Windows-1252 und
ISO-8859-1. Windows-, Unix-, klassische Mac- und gemischte Zeilenenden
bleiben erhalten. Ändert eine andere App eine geöffnete Datei, warnt MacPad
vor dem Überschreiben und bietet sichere nächste Schritte an.

Bei jedem normalen Start öffnet MacPad genau ein neues leeres Dokument.
Gesicherte Dokumente werden nicht automatisch erneut geöffnet und bleiben
über „Zuletzt verwendet“ erreichbar. MacPad ist kostenlos und wird als
privates, nicht kommerzielles Hobbyprojekt entwickelt. Die App hat kein
Konto und enthält keine Werbung, Abonnements, In-App-Käufe, Spenden, Analyse
oder Cloud-Synchronisierung. Dokumentinhalte bleiben auf deinem Mac und
werden von MacPad nicht übertragen.

Benötigt macOS 14 oder neuer. Englisch und Deutsch enthalten.

### Schlüsselwörter

Klartext,Editor,Notizen,Schreiben,UTF-8,Kodierung,Tabs,Menüleiste,offline,Zeilenenden

Länge: 86 UTF-8-Bytes.

### Entwurf der Versionshinweise

Erste Veröffentlichung im Mac App Store. MacPad bietet schnelle, native
Klartextbearbeitung, optionalen Zugriff über die Menüleiste, Englisch und
Deutsch, Tabs, die Erhaltung von Kodierungen und Zeilenenden, sicheren
Umgang mit externen Änderungen und „Zuletzt verwendet“ für gesicherte
Dokumente.

Dieser Text ist ein Entwurf für die künftig freigegebene Website, das
Prüfpaket oder den Versionsverlauf zum Start. Er ist kein Feld „Neu in
dieser Version“ in App Store Connect. Apple stellt dieses Feld für die erste
Version nicht bereit und verlangt es für spätere Versionen.

### Bildschirmfoto-Texte

1. Neuer Klartext direkt aus der Menüleiste
2. Native Tabs, Suche und klare Statusanzeige
3. Schutz bei Änderungen durch andere Apps

## Public URL contract

The owner approved these repository-local destinations:

- product and Website: `https://macpad.net`;
- customer support: `https://macpad.net/support`;
- privacy policy: `https://macpad.net/privacy`.

The URLs are compiled preparation, not production verification. macpad.net
does not yet serve the correct MacPad site, so no candidate may be released
until Shared Services verifies the exact anonymous English and German pages.

The remaining public contract must still supply stable, anonymous English
and German destinations for:

- product and marketing information;
- Help and documentation;
- security reporting;
- release notes;
- direct-user migration and update guidance; and
- the final Mac App Store listing.

The App Store Help menu now exposes the approved Support and Privacy routes,
but still omits unconfigured Help and Security commands as well as every
direct update or source-repository route. Unresolved routes must not fall
back to GitHub, SourceForge, or an invented hostname.

The following page copy is ready for publication only after the bracketed
owner inputs are resolved and the complete page is reviewed on the approved
domain.

### Privacy page — English

**MacPad Privacy**

Last reviewed: 29 August 2026

MacPad is a native plain-text editor for macOS. It does not require an
account and contains no advertising, analytics, tracking, cloud sync, or
third-party SDKs.

Documents and document contents are processed only on your Mac and are not
transmitted by MacPad. MacPad stores local preferences and recent-document
access metadata. It does not store document text or document-session state
in preferences.

File access occurs only for files you choose through macOS. The App Store
build uses app-scoped security bookmarks to restore permitted access.
MacPad uses local SHA-256 digests only to detect whether an open file has
changed.

This policy covers the MacPad app. Following a future approved external
link opens the public page in your default browser; the website's own
privacy notice covers website processing.

This statement was reviewed against the source on 29 August 2026. It must
be reviewed again before release and whenever dependencies, networking,
telemetry, account features, or data handling change.

### Datenschutzseite — Deutsch

**Datenschutz bei MacPad**

Zuletzt geprüft: 29. August 2026

MacPad ist ein nativer Klartext-Editor für macOS. Die App benötigt kein
Konto und enthält keine Werbung, Analyse, Nachverfolgung,
Cloud-Synchronisierung oder Drittanbieter-SDKs.

Dokumente und Dokumentinhalte werden nur auf deinem Mac verarbeitet und
von MacPad nicht übertragen. MacPad speichert lokale Einstellungen und
Zugriffsmetadaten für zuletzt verwendete Dokumente. Dokumenttext und
Dokument-Sitzungen werden nicht in den Einstellungen gespeichert.

Der Dateizugriff erfolgt nur auf Dateien, die du über macOS auswählst. Die
App-Store-Version verwendet app-bezogene Sicherheitslesezeichen, um
erlaubten Zugriff wiederherzustellen. Lokale SHA-256-Prüfwerte dienen
ausschließlich dazu, Änderungen an geöffneten Dateien zu erkennen.

Diese Erklärung gilt für die MacPad-App. Ein künftig freigegebener externer
Link öffnet die öffentliche Seite im Standardbrowser; für die Verarbeitung
der Website gilt deren eigene Datenschutzerklärung.

Diese Erklärung wurde am 29. August 2026 mit dem Quellcode abgeglichen. Sie
muss vor der Veröffentlichung sowie bei Änderungen an Abhängigkeiten,
Netzwerkzugriff, Telemetrie, Kontofunktionen oder Datenverarbeitung erneut
geprüft werden.

### Support page — English

**MacPad Support**

MacPad works without an account.

For help, bug reports, or feature requests, use
[OWNER INPUT REQUIRED: final public support contact]. Include the MacPad
version, macOS version, expected result, actual result, and reproducible
steps. Do not attach private document contents unless they are essential
and you intentionally choose to share them.

Report security concerns through
[OWNER INPUT REQUIRED: final public security-reporting route].

### Supportseite — Deutsch

**MacPad-Support**

MacPad funktioniert ohne Konto.

Für Hilfe, Fehlerberichte oder Funktionswünsche nutze
[EINGABE DES EIGENTÜMERS ERFORDERLICH: endgültiger öffentlicher
Support-Kontakt]. Nenne MacPad-Version, macOS-Version, erwartetes Ergebnis,
tatsächliches Ergebnis und reproduzierbare Schritte. Hänge keine privaten
Dokumentinhalte an, außer sie sind unbedingt nötig und du entscheidest dich
bewusst dafür.

Melde Sicherheitsprobleme über
[EINGABE DES EIGENTÜMERS ERFORDERLICH: endgültiger öffentlicher
Sicherheits-Meldeweg].

### Help page — English

**MacPad Help**

1. Choose File > New Document or press Command-N to create a blank document
   in the active tab group, or a window when no editor exists. New Tab uses
   Command-T; New Window always creates a separate window. The optional
   menu-bar item also opens a new empty window.
2. Use File > Open for an existing plain-text file. Open Recent lists files
   previously selected in MacPad.
3. Use Save or Save As to write the document. Save As lets you choose a
   supported encoding. MacPad preserves the document's line-ending style
   and shows the current mode in the status bar.
4. Use native windows and tabs to organize documents. Find and Replace,
   font, zoom, word wrap, and the status bar are available from the menus.
5. If another app changes an open file, read MacPad's warning before
   reloading or overwriting anything.
6. A normal relaunch opens one blank document. Reopen a saved document from
   Open Recent; MacPad does not restore or store document sessions.
7. Print uses the standard macOS print panel.

MacPad has no account or cloud synchronization. Choose the file location
that fits your own backup and synchronization needs.

### Hilfeseite — Deutsch

**MacPad-Hilfe**

1. Wähle Ablage > Neues Dokument oder drücke Command-N, um ein leeres
   Dokument im aktiven Tab-Bereich zu erstellen; ohne Editor entsteht ein
   Fenster. Neuer Tab verwendet Command-T, Neues Fenster bleibt getrennt.
   Das optionale Menüleisten-Symbol öffnet ebenfalls ein leeres Fenster.
2. Öffne eine vorhandene Klartextdatei über Ablage > Öffnen. Zuletzt
   verwendet zeigt Dateien, die zuvor in MacPad ausgewählt wurden.
3. Sichere das Dokument über Sichern oder Sichern unter. Unter Sichern
   unter kannst du eine unterstützte Kodierung wählen. MacPad erhält den
   Zeilenenden-Stil des Dokuments und zeigt den aktuellen Modus in der
   Statusleiste an.
4. Ordne Dokumente in nativen Fenstern und Tabs. Suchen und Ersetzen,
   Schrift, Zoom, Zeilenumbruch und Statusleiste findest du in den Menüs.
5. Wenn eine andere App eine geöffnete Datei ändert, lies die Warnung von
   MacPad, bevor du etwas neu lädst oder überschreibst.
6. Nach einem normalen Neustart öffnet MacPad ein leeres Dokument. Öffne
   gesicherte Dokumente über „Zuletzt verwendet“; MacPad speichert oder
   rekonstruiert keine Dokument-Sitzungen.
7. Drucken verwendet den Standard-Druckdialog von macOS.

MacPad hat kein Konto und keine Cloud-Synchronisierung. Wähle einen
Dateispeicherort, der zu deiner eigenen Sicherungs- und
Synchronisierungslösung passt.

### Migration page — English

**DRAFT — DO NOT PUBLISH UNTIL THE SIGNED MIGRATION MATRIX PASSES**

MacPad is moving from direct downloads to the Mac App Store as its official
installation and update channel. Existing direct-download users should keep
their current app until the final transition instructions on this page are
verified.

The final Developer ID-signed and notarized transition release will point
to this migration page. Only after the Mac App Store listing is verified
live will this page expose the Store link. Exact replacement or removal
steps will be published only after the complete signed direct-to-Store
sequence preserves documents, preferences, recent files, and
permitted file access.

### Migrationsseite — Deutsch

**ENTWURF — NICHT VERÖFFENTLICHEN, BEVOR DIE SIGNIERTE
MIGRATIONSMATRIX BESTANDEN IST**

MacPad wechselt von direkten Downloads zum Mac App Store als offiziellem
Installations- und Aktualisierungskanal. Nutzer der direkt geladenen Version
sollten ihre bestehende App behalten, bis die endgültigen
Übergangshinweise auf dieser Seite verifiziert sind.

Die letzte mit Developer ID signierte und notarisierte Übergangsversion
wird auf diese Migrationsseite verweisen. Erst nachdem der Eintrag im Mac
App Store als live verifiziert wurde, zeigt diese Seite den Store-Link an.
Genaue Austausch- oder Entfernungsschritte werden erst veröffentlicht,
nachdem die vollständige signierte Abfolge von der Direktversion zur
Store-Version Dokumente, Einstellungen, zuletzt verwendete
Dateien und erlaubten Dateizugriff bewahrt.

## App Review notes and test instructions

### English notes

MacPad is a free macOS plain-text editor developed and maintained as a
private, non-commercial hobby project. No login, demo account, network
service, advertising, subscription, in-app purchase, donation, paid support,
paid bundle, or special hardware is present or required. The App Store build
intentionally omits direct-update and source-repository routes. MacPad
requests file access only through standard Open and Save panels and uses
app-scoped security bookmarks for files the reviewer selects. Printing uses
the standard macOS print panel.

### English review steps

1. Launch on macOS 14 or later and type in a new document.
2. Save through the standard panel, quit, relaunch, and confirm that exactly
   one new blank document opens rather than the saved document.
3. Use Open Recent to reopen the saved document.
4. Use Save As and inspect the encoding control. Confirm that the status bar
   shows the current line-ending mode and that saving preserves it.
5. Change the saved file in another app, return to MacPad, and verify the
   external-change warning and reload path.
6. Enable the optional menu-bar item and create a new empty window from it.
7. Verify English and German through the macOS per-app language setting.
8. No account or credentials are required. Support and Privacy use the
   approved macpad.net routes. Help and Security remain absent. Do not use
   this candidate for review until the configured routes are verified live.

### Deutsche Hinweise

MacPad ist ein kostenloser Klartext-Editor für macOS und wird als nicht
kommerzielles Hobbyprojekt gepflegt. Die App enthält weder Anmeldung,
Demokonto, Netzwerkdienst, Werbung, Abonnement, In-App-Kauf, Spende,
bezahlten Support noch ein kostenpflichtiges Bundle; besondere Hardware ist
nicht erforderlich. Die App-Store-Version enthält absichtlich weder direkte
Aktualisierung noch Verweise auf das Quellcode-Repository. MacPad fordert
Dateizugriff nur über die Standarddialoge zum Öffnen und Sichern an und
verwendet app-bezogene Sicherheitslesezeichen für Dateien, die der Prüfer
auswählt. Zum Drucken wird der Standard-Druckdialog von macOS verwendet.

### Deutsche Prüfschritte

1. Starte die App unter macOS 14 oder neuer und schreibe in ein neues
   Dokument.
2. Sichere es über den Standarddialog, beende die App, starte sie neu und
   prüfe, dass genau ein neues leeres Dokument statt des gesicherten
   Dokuments geöffnet wird.
3. Öffne das gesicherte Dokument über „Zuletzt verwendet“.
4. Öffne Sichern unter und prüfe die Einstellung für die Kodierung.
   Bestätige, dass die Statusleiste den aktuellen Zeilenenden-Modus zeigt
   und dass er beim Sichern erhalten bleibt.
5. Ändere die gesicherte Datei in einer anderen App, kehre zu MacPad zurück
   und prüfe die Warnung sowie den Weg zum Neuladen.
6. Aktiviere optional das Menüleisten-Symbol und öffne darüber ein neues
   leeres Fenster.
7. Prüfe Englisch und Deutsch über die macOS-Einstellung für die
   App-Sprache.
8. Es sind kein Konto und keine Zugangsdaten nötig. Support und Datenschutz
   verwenden die freigegebenen macpad.net-Routen. Hilfe und Sicherheit
   bleiben ohne Befehl. Dieser Kandidat darf erst nach der Live-Prüfung der
   konfigurierten Routen zur Prüfung verwendet werden.

## Draft owner decisions

Nothing in this table changes external state. Each live value or attestation
requires the named owner gate.

| Field | Repository draft | Owner gate |
| --- | --- | --- |
| Primary category | Utilities, matching public.app-category.utilities in Xcode | Confirm in App Store Connect |
| Age rating | No objectionable content, unrestricted web access, gambling, contests, messaging, user-generated content, advertising, or purchases in the app | Reconfirm every answer in Apple's live questionnaire; do not assert the calculated rating in advance |
| App Privacy | No data collected | Re-audit the final binary, then enter and attest in App Store Connect |
| Export compliance | Local SHA-256 file hashing; no network communication or user-facing encryption feature | Complete Apple's live legal determination before adding ITSAppUsesNonExemptEncryption or making an export claim |
| Content rights | Repository artwork plus Apache-2.0 code and license evidence are available | Owner reviews the evidence and attests the rights |
| EU DSA | No status inferred | Owner determines and declares trader status; Apple says it cannot make that determination |
| Store price | Free at launch | Owner confirms the free price and required tax category in App Store Connect; no paid price or bundle is proposed |
| Monetization | None: no ads, subscriptions, in-app purchases, donations, paid support, or paid bundle | Paid-app agreements and revenue-oriented tax/banking setup are not launch requirements; any future monetization is a new owner decision and product review |
| Storefront availability | Recommend all Apple storefronts where the owner can meet the applicable legal, support, privacy, and compliance obligations | Owner makes the final live storefront selection; EU availability does not replace the separate DSA self-assessment |
| Apple Developer Program | Required for App Store distribution; membership status is not established by repository evidence | Owner enrolls or renews separately and treats the membership fee as a hobby expense |
| Store record | MacPad and bilingual copy are drafts | Owner confirms name availability, primary language, immutable SKU, seller and copyright text, and App Review contact |
| Accessibility | The app has VoiceOver labels and identifiers, but no Store label is claimed here | Test all common tasks before the owner enters any Accessibility Nutrition Label |
| Public routes | Unresolved | Owner approves the final HTTPS contract after anonymous English and German verification |
| Signing and release | Not performed | Separate approvals are required for identifiers, team/signing, notarization, upload, review submission, release, and publication |

The App Store is the approved official installation and update channel at
launch. A Direct build is limited to repository-local verification and one
final legacy-user transition release. It is not a second long-term customer
distribution channel.

No repository visibility or SourceForge change may occur until permanent
bilingual public routes, the exact signed migration sequence, a verified
live Mac App Store listing, and the separate owner approvals in the binding
cross-project cutover documents have passed. Permanent SourceForge deletion
requires its own later owner approval.

## Production identifier proposal

The project remains on the preparation placeholder local.macpad.app. This
preparation package does not change it.

The owner must choose exactly one production option:

1. **Recommended: com.anvilfilbert.MacPad** — aligns with the public
   publisher namespace.
2. **Alternative: app.macpad.editor** — stronger product naming, but only
   if the brand namespace is controlled for the long term.

Changing the bundle identifier changes the UserDefaults preference domain,
recent-document identity, sandbox container, and code-signing identity
association. Direct and Store builds should normally adopt the same approved
production identifier before the first App Store upload. Apple does not
allow the Store bundle identifier to be changed after a build is uploaded.

Do not implement a preference, session, recent-file, or container migration
until the owner selects the identifier. After selection, design one
fail-closed migration for the selected identifier, add focused tests, and
validate it through the exact signed sequence below.

## Legacy-user signed migration gate

Required sequence:

installed v1.3.1-or-earlier Direct app → Developer ID-signed and notarized
final transition build → production Mac App Store build

No build in that exact sequence has been produced or tested. Every matrix
cell is therefore fail-closed.

| Concern | Direct app → final transition build | Final transition build → Store build | Required evidence |
| --- | --- | --- | --- |
| Bundle identifier and signing association | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | Approved identifier and exact signed identities behave as designed |
| Preferences | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | Existing settings migrate once without loss or duplication |
| Sandbox container | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | Container behavior and any migration are verified on a clean supported Mac |
| Saved documents | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | Open, edit, save, quit, and relaunch preserve the file |
| Dirty documents | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | Save, Don't Save, and Cancel choices remain explicit; no content is silently discarded |
| Clean relaunch contract | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | Relaunch opens exactly one blank document, does not restore legacy session data, and leaves recent-document access intact |
| Recent files | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | Native recents and repository-managed references remain usable or fail clearly |
| Security-scoped bookmarks | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | Bookmark refresh remains balanced for explicit opens, saves, and Open Recent; inaccessible files fail clearly |
| Conflict and recovery behavior | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | External changes, reload, and recovery choices do not overwrite content silently |
| Help, Support, Privacy, and Security | COMPILED / NOT LIVE-VERIFIED | COMPILED / NOT LIVE-VERIFIED | Every configured domain route opens the correct anonymous MacPad page in English and German; unconfigured Help and Security routes remain absent |
| Migration and update guidance | NOT TESTED / OWNER-GATED | NOT TESTED / OWNER-GATED | The transition build points only to the verified migration page; that page exposes the Store link after live-listing verification |

Do not publish instructions telling a user to overwrite, replace, remove, or
delete an existing app until this exact signed matrix passes. A successful
unsigned build or archive does not satisfy the matrix.

## Private-repository readiness

This is a preparation audit, not permission to change repository visibility.
The binding cutover plan establishes the following future checks:

| Area | Current preparation conclusion | Required post-adaptation evidence |
| --- | --- | --- |
| GitHub Actions | Private execution consumes the account's private Actions allowance | Owner confirms allowance and expected runner use |
| Customer releases | Current public release publication and unauthenticated GitHub Releases cannot remain customer infrastructure | Public domain and Mac App Store replace them before privacy |
| Source checkout | Any unauthenticated origin/main fetch is private-incompatible | Authenticated clone and fetch pass after adaptation |
| CodeQL | Eligibility is not assumed | Run a real private-repository eligibility and workflow check |
| Environments | Protection behavior is not assumed | Verify required environments and protections after adaptation |
| Reusable workflows | Access across private boundaries is not assumed | Exercise each required caller after adaptation |
| Artifacts and retention | Availability and retention can differ under the account plan | Verify the actual retention and authorized download path |
| Artifact attestations | The binding plan treats private GitHub attestations as requiring Enterprise Cloud and as internal provenance, not customer trust | Confirm the account plan; do not make a customer dependency |

The repository-safe final-transition record may preserve only:

- the final direct-release SHA-256 checksum;
- the immutable source commit and tag;
- release notes; and
- pass or fail status for signing, notarization, and stapling.

Keep the Developer ID identity summary, Apple Team or account identifiers,
certificate details, notarization log, credentials, and other identifying
evidence in an owner-approved private location outside every repository.

If a valid public attestation bundle already exists before the public
workflow is removed, it may be preserved as optional private historical
evidence. Do not require or invent a final-transition attestation after the
binding plan removes that workflow.

## Official Apple references

These sources were reviewed on 2026-08-29. Recheck them before live entry or
submission because Apple can change requirements.

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) — name and subtitle limits, required macOS privacy URL, bundle-ID immutability, category, age rating, content rights, and SKU.
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) — promotional text, description, keyword, Support URL, review-note, and What's New limits.
- [Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information) — localized Store metadata and primary-language fallback.
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) — required 16:10 Mac screenshot sizes.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — accurate product representation, review access, content rights, privacy, and Store review expectations.
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) — Apple's collection definition, on-device processing, third-party partners, tracking, and required public privacy link.
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy) — App Store Connect entry and maintenance.
- [Adding a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk) — valid manifest requirements and macOS bundle placement.
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) — current platform scope and declaration rules.
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) — listed SDK manifest and signature requirements.
- [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/) — mandatory live questionnaire and region-specific result.
- [Export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/) — developer responsibility for the live determination.
- [ITSAppUsesNonExemptEncryption](https://developer.apple.com/documentation/BundleResources/Information-Property-List/ITSAppUsesNonExemptEncryption) — Info.plist declaration semantics.
- [EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/) — required self-assessment and public contact consequences.
- [App pricing and availability](https://developer.apple.com/help/app-store-connect/reference/pricing-and-availability/app-pricing-and-availability) — free-price, tax-category, and storefront fields required before submission; a paid agreement applies only when the price is not free.
- [Sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/) — free apps are distributed under the Apple Developer Program License Agreement; selling apps or offering in-app purchases requires a separate paid agreement.
- [Apple Developer Program](https://developer.apple.com/programs/) — membership enables App Store distribution, including free apps.
- [Manage availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store) — storefront selection.
- [Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/) — current voluntary start and common-task evaluation standard.
- [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id) — explicit App ID and Xcode identifier relationship.

## Binding repository references

For MacPad Desktop pricing and monetization, the owner-approved free hobby
model in this document and the MacPad-specific plan supersedes earlier paid
or commercial draft language in the cross-project records. Those records
remain unchanged and authoritative for the shared cutover sequence and for
MacPad Mobile decisions outside this document's scope.

- [Private Source and App Store Distribution Cutover Design](superpowers/specs/2026-08-28-private-source-app-store-cutover-design.md)
- [Private Source and App Store Distribution Cutover Plan](superpowers/plans/2026-08-28-private-source-app-store-cutover.md)
- [MacPad English/German App Store Preparation Plan](superpowers/plans/2026-08-28-macpad-en-de-app-store-preparation.md)

## Acceptance checks

This preparation package is ready for review only when all repository-local
checks below pass for the exact diff:

- only MacPad Desktop Store-preparation and verification documentation changes;
- Package.swift and the source audit still match the evidence above;
- local.macpad.app remains the project placeholder;
- no PrivacyInfo.xcprivacy is added;
- the launch model remains free with no advertising, subscription, in-app
  purchase, donation, paid support, paid bundle, paid price proposal,
  break-even target, or commercial launch assertion;
- Paid Apps Agreement and revenue-oriented tax/banking setup are not listed
  as launch requirements, while Apple Developer Program membership remains
  an owner-controlled hobby expense;
- the repository recommendation is a free Store price and final owner
  selection of eligible storefronts after legal and compliance review;
- EU DSA trader status remains an owner legal self-assessment and is not
  inferred from the hobby-project model;
- the two descriptions begin with the required positioning and put
  optional menu-bar access first;
- each subtitle is at most 30 characters, each promotional text is at most
  170 characters, and each keyword field is at most 100 UTF-8 bytes;
- exactly three screenshot captions exist in each language;
- the exact public URL owner-input sentence is present and no public URL or
  contact is invented;
- all signed-migration rows remain NOT TESTED / OWNER-GATED;
- current direct-download README instructions remain unchanged;
- scripts/verify-public-repo.sh and scripts/check-localizations.sh pass;
- the exact-candidate Swift tests and unsigned App Store preflight are
  reported separately with their real results; and
- git diff --check passes.

These checks verify repository preparation only. They do not verify a
production signature, notarization, submission, approval, distribution, a
live Store listing, a migration from signed builds, a public domain,
SourceForge retirement, or private-repository operation.
