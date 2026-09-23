# rust_ui

Les widgets [iced](https://iced.rs) partagés entre **Robot-Rust** (chaîne
d'annotation d'un robot désherbeur) et **ThermoSim** (simulateur thermique de
bâtiments). Deux applications sans aucun rapport, la même fenêtre.

```toml
rust_ui = { git = "https://github.com/webshaker/RustUI" }
```

## Ce qu'il y a dedans

| module | |
|---|---|
| `menu` | barre de menu et déroulants |
| `context_menu` | le clic droit, rabattu pour rester visible |
| `tree` | arbre repliable, l'état d'ouverture chez l'appelant |
| `layer` | **le rognage GPU** — voir plus bas |
| `separator` | une ligne d'un pixel |
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

## Ce qu'il ne fait pas, et c'est ce qui le rend possible

Il ne tient **aucun état**. Il ne possède pas la boucle de l'application, il ne
sait pas ce qu'on affiche, il ne décide de rien. Ce n'est qu'un paquet de
fonctions qui rendent des `Element`, plus quelques structures pour les décrire.
L'état d'ouverture d'un arbre, le menu déroulé, la sélection : tout cela vit
chez l'appelant.

Et il n'a **qu'une seule dépendance**, `iced`. Le jour où quelqu'un en ajoute
une autre, elle se voit dans `Cargo.toml`.

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
