//! Les fenetres modales : un voile sombre, une boite centree — **et de quoi
//! remplir un formulaire dedans**.
//!
//! ```ignore
//! use rust_ui::modal::{modal, title, field, cancel_confirm, error};
//!
//! modal(
//!     column![
//!         title("Nouvelle ferme"),
//!         field("Nom", &f.nom, "le nom de l exploitation",
//!               |s| Msg::NomEdite(s), Some("popup-nom"), Some(Msg::Creer)),
//!         error(&f.erreur),
//!         cancel_confirm("Creer", Some(Msg::Creer), Msg::Fermer),
//!     ].spacing(12).into(),
//!     420.0,
//! )
//! ```
//!
//! # Le voile ne ferme rien au clic, et c est delibere
//!
//! Les modales ont toutes un bouton. Un clic malheureux a cote ne doit pas
//! perdre un formulaire a moitie rempli — c est le genre de raccourci qui
//! parait pratique jusqu au jour ou il coute une saisie.
//!
//! # Ce qui est ici et ce qui ne l est pas
//!
//! La **coquille** et les briques de formulaire, rien d autre. Le CONTENU
//! d une modale appartient a son application : « nouvelle ferme », « choisir
//! un materiau » n ont rien a faire dans une bibliotheque partagee.
//!
//! La frontiere s est lue toute seule dans le fichier d origine : les cent
//! premieres lignes ne connaissaient que des `Element`, les six cents
//! suivantes parlaient de champs, d allees et de sequences.

use iced::widget::container::Style;
use iced::widget::{
    Space, button, center, column, container, horizontal_rule, row, text, text_input,
};
use iced::{Alignment, Border, Color, Element, Length};

use crate::colors::*;

/// La boite modale : un voile sombre plein ecran, une boite centree dessus.
///
/// A empiler par-dessus l application, typiquement dans un `stack!`.
pub fn modal<'a, Message: Clone + 'a>(
    content: Element<'a, Message>,
    width: f32,
) -> Element<'a, Message> {
    let boite = container(content)
        .width(width)
        .padding(20)
        .style(|_| Style {
            background: Some(POPUP_BG.into()),
            border: Border {
                color: BORDER,
                width: 1.0,
                radius: 8.0.into(),
            },
            ..Default::default()
        });
    container(center(boite))
        .width(Length::Fill)
        .height(Length::Fill)
        .style(|_| Style {
            background: Some(SCRIM.into()),
            ..Default::default()
        })
        .into()
}

/// Un titre de modale, souligne.
pub fn title<'a, Message: 'a>(t: impl Into<String>) -> Element<'a, Message> {
    let t = t.into();
    column![text(t).size(18).color(Color::WHITE), horizontal_rule(1)]
        .spacing(8)
        .into()
}

/// Un bouton de modale. `message` a `None` : grise et inerte.
///
/// `primary` teinte l action principale — celle que la touche Entree ferait.
pub fn button_<'a, Message: Clone + 'a>(
    label: &'a str,
    message: Option<Message>,
    primary: bool,
) -> Element<'a, Message> {
    let actif = message.is_some();
    let mut b = button(text(label).size(13))
        .padding([6, 16])
        .style(move |_theme, statut| {
            let fond = match (primary, statut) {
                (true, button::Status::Hovered) => Color::from_rgb(0.3, 0.55, 0.85),
                (true, _) => SELECTION,
                (false, button::Status::Hovered) => Color::from_rgb(0.32, 0.32, 0.32),
                (false, _) => Color::from_rgb(0.25, 0.25, 0.25),
            };
            button::Style {
                background: Some(if actif { fond } else { Color::from_rgb(0.2, 0.2, 0.2) }.into()),
                text_color: if actif { Color::WHITE } else { TEXT_MUTED },
                border: Border {
                    radius: 4.0.into(),
                    ..Default::default()
                },
                ..Default::default()
            }
        });
    if let Some(m) = message {
        b = b.on_press(m);
    }
    b.into()
}

/// La paire « Annuler / <action> », alignee a droite.
///
/// `cancel` est le message de fermeture — il se passe en parametre plutot que
/// d etre cable, sinon le widget ne servirait qu a une application.
pub fn cancel_confirm<'a, Message: Clone + 'a>(
    confirm_label: &'a str,
    confirm: Option<Message>,
    cancel: Message,
) -> Element<'a, Message> {
    row![
        Space::with_width(Length::Fill),
        button_("Annuler", Some(cancel), false),
        button_(confirm_label, confirm, true),
    ]
    .spacing(8)
    .into()
}

/// Une ligne « libelle + saisie ».
///
/// `id` : le champ qui recoit le focus a l ouverture de la modale — sans lui,
/// il faut cliquer avant de taper. `submit` : ce que la touche Entree envoie.
///
/// L `hint` doit dire ce que le champ ATTEND, pas donner un exemple : une
/// indication grise qui ressemble a une valeur se lit comme une valeur deja
/// saisie. Une planche en jachere affichee « carotte » en gris s est deja lue
/// comme une planche de carotte.
pub fn field<'a, Message: Clone + 'a>(
    label: &'a str,
    value: &'a str,
    hint: &'a str,
    on_edit: impl Fn(String) -> Message + 'a,
    id: Option<&'static str>,
    submit: Option<Message>,
) -> Element<'a, Message> {
    let mut saisie = text_input(hint, value).on_input(on_edit).size(13).padding(6);
    if let Some(id) = id {
        saisie = saisie.id(id);
    }
    if let Some(m) = submit {
        saisie = saisie.on_submit(m);
    }
    row![text(label).size(13).color(TEXT_SECONDARY).width(110), saisie]
        .spacing(8)
        .align_y(Alignment::Center)
        .into()
}

/// Un message d erreur sous un formulaire, ou rien.
///
/// Rend un espace de hauteur nulle quand il n y a rien a dire : l appelant
/// l insere inconditionnellement et n a aucun `if` a ecrire.
pub fn error<'a, Message: 'a>(e: &'a Option<String>) -> Element<'a, Message> {
    match e {
        Some(e) => text(e.as_str()).size(12).color(RED).into(),
        None => Space::with_height(0).into(),
    }
}
