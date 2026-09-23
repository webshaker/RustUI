//! The palette: dark greys, light text. Taken from SimulateurThermique.
//!
//! Noms en anglais comme tout le reste de l'API publique de ce crate : il est
//! fait pour etre partage, et l'autre projet qui le consommera est deja en
//! anglais. Les commentaires, eux, restent en francais — c'est la convention
//! du depot, et c'est ce que lit celui qui les ecrit.
//!
//! **Rien de metier ici.** Les couleurs des collets ont quitte ce fichier pour
//! `client/src/ui/couleurs_ferme.rs` : une bibliotheque generique qui porterait
//! « la couleur d'un collet detecte par le reseau » ne serait generique que de
//! nom.

use iced::Color;

pub const MENU_BG: Color = Color::from_rgb(0.18, 0.18, 0.18);
pub const MENU_BG_HOVER: Color = Color::from_rgb(0.25, 0.25, 0.25);
pub const MENU_BG_OPEN: Color = Color::from_rgb(0.30, 0.30, 0.30);
pub const PANEL_BG: Color = Color::from_rgb(0.12, 0.12, 0.12);
pub const VIEW_BG: Color = Color::from_rgb(0.08, 0.08, 0.08);
pub const POPUP_BG: Color = Color::from_rgb(0.15, 0.15, 0.15);
/// Le voile sombre qui passe sous une modale.
pub const SCRIM: Color = Color::from_rgba(0.0, 0.0, 0.0, 0.6);
pub const BORDER: Color = Color::from_rgb(0.4, 0.4, 0.5);

pub const TEXT: Color = Color::from_rgb(0.85, 0.85, 0.85);
pub const TEXT_SECONDARY: Color = Color::from_rgb(0.6, 0.6, 0.6);
/// Estompe : ce qui existe mais n'est pas disponible.
pub const TEXT_MUTED: Color = Color::from_rgb(0.45, 0.45, 0.45);
pub const SELECTION: Color = Color::from_rgb(0.2, 0.45, 0.75);

pub const GREEN: Color = Color::from_rgb(0.3, 0.9, 0.3);
pub const ORANGE: Color = Color::from_rgb(0.9, 0.7, 0.3);
pub const RED: Color = Color::from_rgb(1.0, 0.35, 0.35);
