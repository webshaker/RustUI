//! Barre de menu et deroulants, **generiques** : la barre est dans la mise en
//! page, le deroulant est un calque du `stack!` avec une zone cliquable qui
//! ferme le menu.
//!
//! # L'usage, en entier
//!
//! ```ignore
//! let menus = vec![
//!     Menu::new("Fichier", vec![
//!         MenuItem::new("Ouvrir...", MonMessage::Ouvrir),
//!         MenuItem::when("Enregistrer", projet_ouvert, MonMessage::Enregistrer),
//!     ]),
//!     Menu::new("Aide", vec![MenuItem::new("A propos", MonMessage::APropos)]),
//! ];
//!
//! // dans la mise en page
//! menu_bar(&menus, ouvert, MonMessage::BasculerMenu)
//! // et en calque du stack!
//! menu_dropdown(&menus, ouvert, MonMessage::FermerMenus)
//! ```
//!
//! # Deux choix qui rendent l'usage simple
//!
//! **Le menu ouvert est un `Option<usize>`**, pas une enumeration. Une
//! enumeration serait propre a une application, donc le widget ne serait
//! partageable par aucune autre — et l'appelant devrait ecrire un `match` de
//! plus. Un indice se lit dans la liste qu'il a lui-meme declaree.
//!
//! **Les decalages se calculent**, ils ne se declarent plus. Ils etaient des
//! constantes a la main (`4.0`, `88.0`, `164.0`) qu'il fallait recalculer a
//! chaque libelle ajoute — et se tromper y decale un deroulant sans que rien
//! ne le signale.

use iced::widget::container::Style;
use iced::widget::{Space, button, column, container, mouse_area, row, text};
use iced::{Alignment, Border, Color, Element, Length, Padding};

use crate::colors::*;
use crate::separator::horizontal_separator;

/// Hauteur de la barre : padding 4 + bouton (5 + texte 14 + 5) + 4 + separateur.
const HAUTEUR_BARRE: f32 = 36.0;
const LARGEUR_DEROULANT: f32 = 230.0;
/// Le padding horizontal d'un bouton de barre, des deux cotes.
const PADDING_BOUTON: f32 = 15.0;
/// Largeur moyenne d'un caractere a la taille 14. Approximatif, et suffisant :
/// un deroulant qui s'ouvre a quelques pixels pres ne gene personne.
const LARGEUR_CARACTERE: f32 = 7.3;

/// Une ligne de deroulant.
pub struct MenuItem<Message> {
    pub label: &'static str,
    /// `None` : l'item est grise, sans action.
    pub message: Option<Message>,
}

impl<Message> MenuItem<Message> {
    pub fn new(label: &'static str, message: Message) -> Self {
        Self { label, message: Some(message) }
    }

    /// Actif seulement si la condition tient. Remplace les fermetures
    /// `si_projet(...)` que chaque appelant reecrivait.
    pub fn when(label: &'static str, condition: bool, message: Message) -> Self {
        Self { label, message: condition.then_some(message) }
    }
}

/// Le bouton d'un item, pour un deroulant comme pour un menu contextuel.
///
/// Partage entre les deux parce qu'ils rendaient le **meme** bouton a un
/// padding pres, et qu'une divergence de style entre le menu et le clic droit
/// se serait vue sans qu'on sache pourquoi.
pub(super) fn item_button<'a, Message: Clone + 'a>(
    item: &MenuItem<Message>,
    padding: [u16; 2],
) -> Element<'a, Message> {
    let actif = item.message.is_some();
    let mut b = button(text(item.label).size(13))
        .width(Length::Fill)
        .padding(padding)
        .style(move |_theme, statut| {
            let fond = match statut {
                button::Status::Hovered if actif => MENU_BG_HOVER,
                _ => MENU_BG,
            };
            button::Style {
                background: Some(fond.into()),
                text_color: if actif { Color::WHITE } else { TEXT_MUTED },
                border: Border::default(),
                ..Default::default()
            }
        });
    if let Some(message) = item.message.clone() {
        b = b.on_press(message);
    }
    b.into()
}

/// Un menu de la barre, et ce qu'il deroule.
pub struct Menu<Message> {
    pub label: &'static str,
    pub items: Vec<MenuItem<Message>>,
}

impl<Message> Menu<Message> {
    pub fn new(label: &'static str, items: Vec<MenuItem<Message>>) -> Self {
        Self { label, items }
    }

    fn largeur(&self) -> f32 {
        2.0 * PADDING_BOUTON + self.label.chars().count() as f32 * LARGEUR_CARACTERE
    }
}

/// Le decalage horizontal du deroulant du menu `i`.
fn decalage<Message>(menus: &[Menu<Message>], i: usize) -> f32 {
    // 4 : le padding de la barre. 2 : l'espacement entre boutons.
    4.0 + menus[..i].iter().map(|m| m.largeur() + 2.0).sum::<f32>()
}

fn bar_button<'a, Message: Clone + 'a>(
    label: &'static str,
    est_ouvert: bool,
    message: Message,
) -> Element<'a, Message> {
    button(text(label).size(14))
        .padding([5, PADDING_BOUTON as u16])
        .style(move |_theme, statut| {
            let fond = if est_ouvert {
                MENU_BG_OPEN
            } else {
                match statut {
                    button::Status::Hovered => MENU_BG_HOVER,
                    _ => Color::TRANSPARENT,
                }
            };
            button::Style {
                background: Some(fond.into()),
                text_color: Color::WHITE,
                border: Border::default(),
                ..Default::default()
            }
        })
        .on_press(message)
        .into()
}

/// La barre, a poser dans la mise en page.
///
/// `basculer` recoit l'indice du menu clique ; a l'appelant de refermer si
/// c'est celui qui etait deja ouvert.
pub fn menu_bar<'a, Message: Clone + 'a>(
    menus: &[Menu<Message>],
    ouvert: Option<usize>,
    basculer: impl Fn(usize) -> Message,
) -> Element<'a, Message> {
    let barre = row(menus
        .iter()
        .enumerate()
        .map(|(i, m)| bar_button(m.label, ouvert == Some(i), basculer(i))))
    .spacing(2)
    .padding(4);

    column![
        container(barre).width(Length::Fill).style(|_| Style {
            background: Some(MENU_BG.into()),
            ..Default::default()
        }),
        horizontal_separator(),
    ]
    .into()
}

/// Le calque deroulant, a empiler par-dessus l'application.
///
/// Rend un espace vide quand rien n'est ouvert : l'appelant l'empile
/// inconditionnellement et n'a aucun `if` a ecrire.
pub fn menu_dropdown<'a, Message: Clone + 'a>(
    menus: &[Menu<Message>],
    ouvert: Option<usize>,
    fermer: Message,
) -> Element<'a, Message> {
    let Some(i) = ouvert.filter(|i| *i < menus.len()) else {
        return Space::new(0, 0).into();
    };

    let boutons: Vec<Element<'a, Message>> =
        menus[i].items.iter().map(|item| item_button(item, [8, 20])).collect();

    let contenu = container(column(boutons))
        .width(Length::Fill)
        .style(|_| Style {
            background: Some(MENU_BG.into()),
            ..Default::default()
        });

    // Bordure noire a gauche, en bas, a droite : un padding sur fond noir.
    let boite = container(contenu)
        .width(LARGEUR_DEROULANT)
        .padding(Padding { top: 0.0, left: 1.0, right: 1.0, bottom: 1.0 })
        .style(|_| Style {
            background: Some(Color::BLACK.into()),
            ..Default::default()
        });

    let positionne = container(boite)
        .width(Length::Fill)
        .align_x(Alignment::Start)
        .padding(Padding {
            top: 0.0,
            left: decalage(menus, i),
            right: 0.0,
            bottom: 0.0,
        });

    // Cliquer n'importe ou sous la barre ferme le menu.
    let zone =
        mouse_area(container(positionne).width(Length::Fill).height(Length::Fill)).on_press(fermer);

    column![Space::with_height(HAUTEUR_BARRE), zone].into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Debug, Clone, PartialEq)]
    struct Essai(usize);

    fn menus() -> Vec<Menu<Essai>> {
        vec![
            Menu::new("Fichier", vec![MenuItem::new("Ouvrir", Essai(0))]),
            Menu::new("Projet", vec![MenuItem::when("Purger", false, Essai(1))]),
            Menu::new("SimPlants", vec![]),
            Menu::new("Aide", vec![]),
        ]
    }

    /// Les decalages se CALCULENT depuis les libelles. Avant, c'etaient des
    /// constantes a la main qu'il fallait reprendre a chaque ajout : inserer
    /// « SimPlants » demandait de recalculer celle d'« Aide », et se tromper
    /// aurait ouvert un deroulant sous le mauvais bouton.
    #[test]
    fn les_decalages_suivent_les_libelles_sans_etre_ecrits() {
        let m = menus();
        assert_eq!(decalage(&m, 0), 4.0, "le premier colle au bord");
        // Chaque decalage est celui du precedent plus sa largeur.
        for i in 1..m.len() {
            let attendu = decalage(&m, i - 1) + m[i - 1].largeur() + 2.0;
            assert!((decalage(&m, i) - attendu).abs() < 1e-6, "menu {i}");
        }
        // Et ils croissent strictement : deux deroulants ne se superposent pas.
        assert!(decalage(&m, 1) < decalage(&m, 2) && decalage(&m, 2) < decalage(&m, 3));
    }

    /// Un indice hors liste ne doit pas paniquer : l'etat de l'application
    /// peut survivre a un menu retire.
    #[test]
    fn un_indice_hors_liste_ne_deroule_rien_et_ne_panique_pas() {
        let m = menus();
        // On ne peut pas inspecter un `Element` ; ce qu'on verifie est qu'il
        // se construit, la ou une indexation nue aurait panique.
        let _ = menu_dropdown(&m, Some(99), Essai(1));
        let _ = menu_dropdown(&m, None, Essai(1));
    }

    /// `MenuItem::when` remplace les fermetures que chaque appelant reecrivait.
    #[test]
    fn un_item_conditionnel_est_inerte_quand_la_condition_tombe() {
        assert!(MenuItem::when("Purger", false, Essai(0)).message.is_none());
        assert_eq!(MenuItem::when("Purger", true, Essai(0)).message, Some(Essai(0)));
    }
}
