//! Les widgets iced partages — **ils ne savent pas ce qu'ils affichent.**
//!
//! Chaque widget est generique sur `Message` : c'est le type de l'application
//! qui l'utilise, et ce crate ne le connait jamais. Il duplique les messages
//! pour les donner aux boutons, sans jamais regarder dedans — d'ou la seule
//! contrainte qu'il pose, `Message: Clone`.
//!
//! ```ignore
//! use rust_ui::{Menu, Item, barre, deroulant, arbre, Node};
//!
//! let menus = vec![Menu::new("Fichier", vec![
//!     MenuItem::new("Ouvrir...", MonMessage::Ouvrir),
//!     MenuItem::when("Enregistrer", il_y_a_quelque_chose, MonMessage::Enregistrer),
//! ])];
//!
//! menu_bar(&menus, ouvert, MonMessage::BasculerMenu)          // la barre
//! menu_dropdown(&menus, ouvert, MonMessage::FermerMenus)       // son calque
//! ```
//!
//! # Ce qu'il y a dedans, et pourquoi
//!
//! ```text
//!   menu        barre + deroulants, et le bouton d item partage
//!   contextuel  le clic droit, rabattu pour rester visible
//!   arbre       repliable, l etat d ouverture chez l appelant
//!   calque      le rognage GPU -- voir plus bas, il a coute deux fois
//!   separator   une ligne d un pixel
//!   couleurs    la palette
//! ```
//!
//! **`calque` est la piece la plus precieuse et la moins evidente.** En iced
//! 0.13, un canvas **ne rogne pas** ce qu'il dessine : `Frame::with_clip` ne
//! s'applique qu'aux maillages et `container.clip(true)` ne pose pas de calque
//! GPU. Une image zoomee deborde donc sur le menu et jusque dans la barre de
//! titre. Ce bug a ete trouve **deux fois** dans le meme depot — la seconde
//! parce que personne n'avait relu les notes de la premiere. C'est exactement
//! ce qu'une bibliotheque partagee evite.
//!
//! # Ce qu'il ne fait PAS, et c'est ce qui le rend possible
//!
//! Il ne tient **aucun etat**. Il ne possede pas la boucle de l'application,
//! il ne sait pas ce qu'on affiche, il ne decide de rien. Ce n'est qu'un
//! paquet de fonctions qui rendent des `Element`, plus quelques structures
//! pour les decrire. L'etat d'ouverture d'un arbre, le menu deroule, la
//! selection : tout cela vit chez l'appelant.
//!
//! # Destine a sortir du depot
//!
//! Ce crate existe pour etre partage avec SimulateurThermique, dont le client
//! porte les memes widgets — `separator.rs` y est deja recopie a l'identique,
//! aux noms pres. Il ne depend de rien du projet : le deplacer ailleurs sera
//! une ligne de `Cargo.toml`.

pub mod colors;
pub mod context_menu;
pub mod layer;
pub mod menu;
pub mod modal;
pub mod separator;
pub mod tree;

pub use colors::*;
pub use context_menu::context_menu;
pub use layer::layer;
pub use menu::{Menu, MenuItem, menu_bar, menu_dropdown};
pub use modal::{cancel_confirm, error, field, modal, title};
pub use separator::{horizontal_separator, vertical_separator};
pub use tree::{Expanded, Node, tree};
