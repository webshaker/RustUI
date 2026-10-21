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

// Convention Crust : un dossier par concept, un fichier par classe
// (application/Application.rsc donne application::application).
#![allow(clippy::module_inception)]

// Sources en Crust (`.rsc`) : `theme/` (palette) et `widgets/`. Les anciens
// chemins (`rust_ui::colors`, `rust_ui::menu`...) restent valables.
include!(concat!(env!("OUT_DIR"), "/crust/root_lib.rs"));

pub use theme::colors;
// Module et fonction de meme nom (`layer`, `modal`, `tree`...) : les deux a la fois.
pub use widgets::{context_menu, layer, menu, modal, separator, tree};

pub use colors::*;
pub use menu::{Menu, MenuItem, menu_bar, menu_dropdown, menu_dropdown_sub};
pub use modal::{cancel_confirm, error, field, title};
pub use separator::{horizontal_separator, vertical_separator};
#[cfg(feature = "canvas")]
pub use widgets::Curve;
pub use tree::{Expanded, Node};

// Lancement d'une application : trait, fenetre, boucle.
pub use application::{AppResult, AppWindow, Application, exit, new_app};

// Application decrite par ecrans : fenetre, ecrans, decoupages, panneaux remplis
// par des fonctions, actions qui modifient directement les donnees.
pub use screens::{Direction, MenuBar, MenuBuilder, Panel, Screen, Splitter, SubMenu, Window};
pub use screens::{copy_to_clipboard, open_file, quit, save_file, show_screen};

// Facade : ce dont une application a besoin, sous le nom de RustUI. Elle n'a
// ainsi pas a dependre d'iced, dont la version n'est choisie qu'ici (les
// `Element` de RustUI et de l'application sont alors forcement compatibles).
pub use iced::{advanced, alignment, clipboard, event, font, keyboard, mouse, time, widget, window};
pub use iced::{
    Alignment, Background, Border, Color, Element, Font, Length, Padding, Pixels, Point, Rectangle, Renderer, Shadow, Size,
    Subscription, Task, Theme, Vector,
};
