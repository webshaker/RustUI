//! Le menu contextuel du clic droit : un calque du `stack!` avec une zone
//! cliquable qui le ferme, et la boite posee au point du clic.
//!
//! **Generique** : il ne connait ni l'application ni ses messages. Ce qu'il
//! faut lui dire, c'est ou le poser, quoi y mettre, et ce que « fermer » veut
//! dire.
//!
//! ```ignore
//! context_menu(position, taille_fenetre, items, MonMessage::Fermer)
//! ```
//!
//! Le bouton d'un item est celui de [`super::menu`] : les deux rendaient le
//! meme, a un padding pres, et une divergence de style entre le menu et le
//! clic droit se serait vue sans qu'on sache pourquoi.

use iced::widget::container::Style;
use iced::widget::{Space, column, container, mouse_area};
use iced::{Border, Element, Length, Padding, Point};

use crate::colors::*;
use crate::menu::{MenuItem, item_button};

const LARGEUR: f32 = 250.0;
/// Hauteur d'un item : padding 7 + texte 13 + padding 7, plus l'espacement.
const HAUTEUR_ITEM: f32 = 31.0;

/// Le calque a empiler par-dessus l'application.
///
/// `position` : coin haut-gauche, en coordonnees fenetre. On le **rabat** pour
/// que la boite reste visible — un menu ouvert au bord de l'ecran sortirait
/// sinon a moitie, et ses derniers items seraient inatteignables.
pub fn context_menu<'a, Message: Clone + 'a>(
    position: Point,
    taille_fenetre: iced::Size,
    items: Vec<MenuItem<Message>>,
    fermer: Message,
) -> Element<'a, Message> {
    let hauteur = 8.0 + items.len() as f32 * HAUTEUR_ITEM;
    let x = position.x.min((taille_fenetre.width - LARGEUR - 4.0).max(0.0)).max(0.0);
    let y = position.y.min((taille_fenetre.height - hauteur - 4.0).max(0.0)).max(0.0);

    let boutons: Vec<Element<'a, Message>> =
        items.iter().map(|item| item_button(item, [7, 16])).collect();

    let boite = container(column(boutons).padding(4))
        .width(LARGEUR)
        .style(|_| Style {
            background: Some(MENU_BG.into()),
            border: Border {
                color: BORDER,
                width: 1.0,
                radius: 4.0.into(),
            },
            ..Default::default()
        });

    let positionne = container(boite).padding(Padding {
        top: y,
        left: x,
        right: 0.0,
        bottom: 0.0,
    });

    // Cliquer n'importe ou ailleurs ferme le menu — au clic gauche comme au
    // droit : rouvrir ailleurs est le geste le plus frequent.
    let fond = mouse_area(container(Space::new(0, 0)).width(Length::Fill).height(Length::Fill))
        .on_press(fermer.clone())
        .on_right_press(fermer);

    iced::widget::stack![fond, positionne].into()
}
