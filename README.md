# rust_ui

Les widgets [iced](https://iced.rs) partagés, et une façon de décrire une
application par écrans, entre **Robot-Rust** (chaîne d'annotation d'un robot
désherbeur), **ThermoSim** (simulateur thermique de bâtiments) et le
**Simulateur électronique**. Des applications sans aucun rapport, la même
fenêtre.

```toml
rust_ui = { git = "https://github.com/webshaker/RustUI" }
```

## Deux façons de s'en servir

1. **Les widgets seuls** (ci-dessous) : l'application garde sa boucle iced, son
   `Message`, son `update` et sa `view`, et y place les widgets de RustUI.
2. **L'application décrite par écrans** (`Window`) : RustUI possède la boucle.
   L'application n'a ni `Message` ni `update` ni dépendance à iced : des
   données (un `Document`), des fonctions qui remplissent les panneaux, et des
   actions `|doc| ...` qui modifient les données. C'est ce que fait le
   Simulateur électronique.

### L'application décrite par écrans

```rust
use rust_ui::{Direction, MenuBar, Panel, Window};

fn main() -> rust_ui::AppResult {
    let mut w = Window::new("Mon application", 1200.0, 700.0);
    let home = w.add_screen("home");               // un écran, par son nom
    home.add_menu(menus);
    home.add_toolbar(outils);
    home.add_statusbar(etat);
    let split = home.add_splitter(Direction::Horizontal, [1, 2, 1]);
    split.add_panel(gauche);                       // une fonction par panneau
    split.add_panel(centre);
    split.add_panel(droite);
    w.add_shortcut("Ctrl+Z", Document::annuler);   // touche → méthode
    home.add_shortcut("Delete", Document::supprimer); // valable sur cet écran
    w.show("home");
    w.run(Document::default())
}

/// Reçoit l'écran affiché, le panneau, les données.
fn gauche(_ecran: &str, p: &mut Panel<Document>, doc: &Document) {
    p.set_width(270.0);                            // sinon : sa part du découpage
    p.add_section("Sélection");
    p.add_line("Valeur", doc.valeur.to_string()).color(rust_ui::ORANGE);
    p.add_row(|r| {
        r.add_button("Pause   (F8)", Document::pause).small();
        r.add_text("EN PAUSE").color(rust_ui::ORANGE);
    });
    p.add_button("Supprimer", Document::supprimer).secondary().enabled(doc.selection.is_some());
}
```

Chaque `add_*` rend l'élément, qui se règle en chaîne (`.color()`,
`.size()`, `.mono()`, `.small()`, `.selected()`...).

| | |
|---|---|
| `Window` | `add_screen`, `show`, `set_icon` (RGBA), `set_icon_file` (option `image`), `screen_from` (l'écran affiché suit les données), `title_from`, `add_shortcut`, `add_modal`, `add_timer` (option `tokio`), `around_actions` (toute action passe par là : historique d'annulation, recalculs), `on_close`, `run` |
| `Screen` | `add_menu`, `add_toolbar`, `add_statusbar`, `add_panel`, `add_splitter`, `add_shortcut` |
| `Panel` : textes | `add_text`, `add_title`, `add_section`, `add_note`, `add_line` (libellé / valeur) |
| `Panel` : commandes | `add_button` (`.primary()`, `.secondary()`, `.small()`, `.accent(c)`, `.tab()`, `.flat()`, `.link()`, `.swatch(c)`, `.tooltip(t)`), `add_image_button` (option `image`), `add_screen_button`, `add_input`, `add_checkbox`, `add_slider` |
| `Panel` : groupes | `add_row`, `add_column`, `add_scroll` (`.from_bottom()` pour un journal), `add_separator`, `add_space`, `add_gap`, `add_swatch` |
| `Panel` : widgets | `add_tree`, `add_canvas` (option `canvas`), `add_curve`, `add_widget` (tout widget qui produit ses propres événements : l'éditeur de code...) |
| `Panel` : réglages | `set_width`, `set_height`, `hide`, `set_scroll`, `set_padding`, `set_spacing`, `set_background`, `set_centered` |
| effets d'une action | `open_file`, `save_file`, `copy_to_clipboard`, `show_screen`, `quit` |
| tests (option `testing`) | `testing::Harness` : la fenêtre sans l'ouvrir — `press("Ctrl+Z")`, `data()`, `layout(w, h)`, `capture(w, h, png)` |

Migration progressive d'une application à `Message` : `Panel::add_legacy`,
`Window::legacy`, `legacy_subscription`, `legacy_first` font passer une vue
d'avant dans un panneau, le temps de la remplacer morceau par morceau.

Exemple complet : `cargo run --example compteur`.

## Les sources sont en Crust

Les fichiers `.rsc` (classes Crust) sont traduits en Rust standard par
`crust-build`, dans `build.rs`. Pour l'application qui utilise RustUI, rien ne
change (l'API est du Rust ordinaire), **mais** `crust-build` est lié par un
chemin vers le dépôt Crust dans WSL : RustUI ne compile que sur cette machine,
**WSL lancé**, et seulement par le `[patch]` local (voir plus bas) tant que
Crust n'est pas publié.

## Ce qu'il y a dedans

| module | |
|---|---|
| `menu` | barre de menu et déroulants |
| `context_menu` | le clic droit, rabattu pour rester visible |
| `tree` | arbre repliable, l'état d'ouverture chez l'appelant |
| `layer` | **le rognage GPU** — voir plus bas |
| `separator` | une ligne d'un pixel |
| `modal` | la coquille modale, et les briques de formulaire dedans |
| `colors` | la palette |

## Il ne connaît pas votre application, et c'est ce qui le rend partageable

Chaque widget est générique sur `Message` : c'est le type de l'application qui
l'utilise, et ce crate ne le voit jamais. Il duplique les messages pour les
donner aux boutons, sans jamais regarder dedans — d'où la seule contrainte
qu'il pose, `Message: Clone`.

```rust
use rust_ui::{Menu, MenuItem, menu_bar, menu_dropdown};

let menus = vec![
    Menu::new("Fichier", vec![
        MenuItem::new("Ouvrir...", MonMessage::Ouvrir),
        MenuItem::when("Enregistrer", il_y_a_quelque_chose, MonMessage::Enregistrer),
    ]),
    Menu::new("Aide", vec![MenuItem::new("A propos", MonMessage::APropos)]),
];

menu_bar(&menus, ouvert, MonMessage::BasculerMenu)      // dans la mise en page
menu_dropdown(&menus, ouvert, MonMessage::FermerMenus)  // en calque du stack!
```

Le menu ouvert est un `Option<usize>` — l'indice dans la liste que vous avez
déclarée — et non une énumération : une énumération serait propre à une
application, donc le widget ne serait partageable par aucune autre.

Et les décalages horizontaux des déroulants **se calculent** depuis les
libellés. Ils étaient des constantes écrites à la main dans les deux projets,
et elles avaient déjà divergé (`4 / 75` d'un côté, `4 / 88 / 164` de l'autre)
pour le même besoin.

## `layer` — la pièce la moins évidente et la plus précieuse

En iced 0.13, **un canvas ne rogne pas ce qu'il dessine** : `Frame::with_clip`
ne s'applique qu'aux maillages et `container.clip(true)` ne pose pas de calque
GPU. Une image zoomée déborde donc sur le menu et jusque dans la barre de
titre.

Ce bug a été trouvé **deux fois** dans Robot-Rust — la seconde parce que
personne n'avait relu les notes de la première. C'est exactement ce qu'une
bibliothèque partagée existe pour ne pas payer une troisième fois.

```rust
rust_ui::layer(mon_canvas)
```

## Ce que les widgets ne font pas, et c'est ce qui les rend possibles

Les widgets ne tiennent **aucun état**. Ils ne possèdent pas la boucle de
l'application (seule `Window` la possède, si on la choisit), ne savent pas ce
qu'on affiche, ne décident de rien. Ce n'est qu'un paquet de fonctions qui rendent des `Element`, plus quelques structures pour les décrire.
L'état d'ouverture d'un arbre, le menu déroulé, la sélection : tout cela vit
chez l'appelant.

Ses dépendances : `iced` (et ses sous-crates, pour l'éditeur de code) et `rfd`
(dialogues de fichier de `Window`). Rien de métier : le jour où quelqu'un en
ajoute une autre, elle se voit dans `Cargo.toml`.

## Deux conventions

**L'API publique est en anglais**, parce que le crate est partagé et que les
deux projets ne le sont pas dans la même langue. Les commentaires sont en
français.

**Les deux projets doivent compiler la même version d'iced**, sinon leurs types
`Element` sont incompatibles et le message d'erreur ne dit pas pourquoi. Les
*features*, elles, peuvent différer : ce sont deux compilations séparées.

## Pendant le développement

Tant que les widgets bougent, une dépendance git demanderait un commit, un
push et une bascule de révision pour chaque retouche. Le `[patch]` l'évite —
dans `.cargo/config.toml`, qui ne se commite pas :

```toml
[patch."https://github.com/webshaker/RustUI"]
rust_ui = { path = "../RustUI" }
```

On dépend par git, épinglé et reproductible, et on édite en local sans
cérémonie.

### ⚠️ Le `[patch]` contamine le `Cargo.lock`

Quand le `[patch]` est actif, cargo écrit l'entrée `rust_ui` **sans ligne
`source`** — comme s'il s'agissait d'un crate local. Le `Cargo.lock` est
commité ; le `.cargo/config.toml`, non. Sur une machine sans le patch, cargo
lit un lock qui décrit un chemin local qui n'existe pas.

**Ce n'est pas lié aux commits, mais à toute commande qui *résout*.** Avec le
patch actif, `cargo update -p rust_ui` réécrit l'entrée en chemin local :

```
Adding rust_ui v0.1.0 (C:\Users\esobo\Documents\RustUI)
Removing rust_ui v0.1.0 (https://github.com/webshaker/RustUI#b90c8fc5)
```

`cargo generate-lockfile`, l'ajout d'une dépendance ou une montée de version
font pareil. Donc : **écarter `.cargo/config.toml` avant toute résolution
destinée à être commitée**, et non « vérifier avant de commiter » — qui
laisserait passer celle-là.

```sh
mv .cargo/config.toml .cargo/config.toml.off
cargo update -p rust_ui        # ou generate-lockfile, ou cargo add...
mv .cargo/config.toml.off .cargo/config.toml
```

Le lock doit porter la ligne `source` :

```
[[package]]
name = "rust_ui"
source = "git+https://github.com/webshaker/RustUI#<sha>"
```

Trouvé par ThermoSim, qui a hérité d'un lock où la ligne manquait — puis a
montré que la recette de contournement était elle aussi incomplète.
