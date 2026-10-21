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

use std::borrow::Cow;

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
pub class MenuItem<Message> {
    pub label: Cow<'static, str>,
    /// `None` : l'item est grise, sans action.
    pub message: Option<Message>,
    /// Sous-menu : s'ouvre a droite au survol.
    pub children: Vec<MenuItem<Message>>,

    pub fn new(label: impl Into<Cow<'static, str>>, message: Message) -> Self {
        Self { label: label.into(), message: Some(message), children: vec![] }
    }

    /// Un sous-menu ; grise s'il est vide.
    pub fn submenu(label: impl Into<Cow<'static, str>>, children: Vec<MenuItem<Message>>) -> Self {
        Self { label: label.into(), message: None, children }
    }

    /// Actif seulement si la condition tient. Remplace les fermetures
    /// `si_projet(...)` que chaque appelant reecrivait.
    pub fn when(label: impl Into<Cow<'static, str>>, condition: bool, message: Message) -> Self {
        Self { label: label.into(), message: condition.then_some(message), children: vec![] }
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
    let mut b = button(text(item.label.to_string()).size(13))
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
pub class Menu<Message> {
    pub label: Cow<'static, str>,
    pub items: Vec<MenuItem<Message>>,

    pub fn new(label: impl Into<Cow<'static, str>>, items: Vec<MenuItem<Message>>) -> Self {
        Self { label: label.into(), items }
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
    label: String,
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
        .map(|(i, m)| bar_button(m.label.to_string(), ouvert == Some(i), basculer(i))))
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
    let f = fermer.clone();
    menu_dropdown_sub(menus, ouvert, None, fermer, move |_| f.clone())
}

/// Hauteur d'une ligne de deroulant (padding 8 + texte 13).
const HAUTEUR_ITEM: f32 = 32.0;

/// Une colonne de boutons sur fond de menu, bordee de noir.
fn boite_menu<'a, Message: 'a>(boutons: Vec<Element<'a, Message>>, largeur: f32) -> Element<'a, Message> {
    let contenu = container(column(boutons)).width(Length::Fill).style(|_| Style {
        background: Some(MENU_BG.into()),
        ..Default::default()
    });
    // Bordure noire a gauche, en bas, a droite : un padding sur fond noir.
    container(contenu)
        .width(largeur)
        .padding(Padding { top: 0.0, left: 1.0, right: 1.0, bottom: 1.0 })
        .style(|_| Style {
            background: Some(Color::BLACK.into()),
            ..Default::default()
        })
        .into()
}

/// Comme `menu_dropdown`, avec des sous-menus : survoler une entree qui en a
/// un envoie `ouvrir_sous(k)` ; `sous` est l'entree dont le sous-menu est ouvert.
pub fn menu_dropdown_sub<'a, Message: Clone + 'a>(
    menus: &[Menu<Message>],
    ouvert: Option<usize>,
    sous: Option<usize>,
    fermer: Message,
    ouvrir_sous: impl Fn(usize) -> Message,
) -> Element<'a, Message> {
    let Some(i) = ouvert.filter(|i| *i < menus.len()) else {
        return Space::new(0, 0).into();
    };

    let boutons: Vec<Element<'a, Message>> = menus[i]
        .items
        .iter()
        .enumerate()
        .map(|(k, item)| {
            if item.children.is_empty() {
                return item_button(item, [8, 20]);
            }
            // Entree a sous-menu : active si une de ses entrees l'est, ouverte au survol.
            let actif = item.children.iter().any(|c| c.message.is_some());
            let tete = MenuItem { label: format!("{}  ›", item.label).into(), message: actif.then(|| ouvrir_sous(k)), children: vec![] };
            mouse_area(item_button(&tete, [8, 20])).on_enter(ouvrir_sous(k)).into()
        })
        .collect();
    let mut groupes = row![boite_menu(boutons, LARGEUR_DEROULANT)];
    if let Some(k) = sous.filter(|k| menus[i].items.get(*k).is_some_and(|it| !it.children.is_empty())) {
        let enfants = &menus[i].items[k].children;
        let largeur = enfants.iter().map(|c| c.label.chars().count() as f32 * LARGEUR_CARACTERE + 42.0).fold(LARGEUR_DEROULANT, f32::max);
        let boutons = enfants.iter().map(|c| item_button(c, [8, 20])).collect();
        // Colle au deroulant : le passage de la souris ne rencontre aucune zone de fermeture.
        groupes = groupes.push(column![Space::with_height(k as f32 * HAUTEUR_ITEM), boite_menu(boutons, largeur)]);
    }
    let boite: Element<'a, Message> = groupes.into();

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
