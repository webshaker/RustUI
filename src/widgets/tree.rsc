//! Un arbre repliable, **generique** : des noeuds, des enfants, un chevron.
//!
//! # Il ne connait pas l'application, et c'est ce qui le rend partageable
//!
//! `Message` est un **parametre**, jamais le type d'une application donnee.
//! Le widget manipule les messages sans jamais regarder dedans : il les
//! duplique pour les donner aux boutons, et c'est tout — d'ou la seule
//! contrainte, `Message: Clone`.
//!
//! ```ignore
//! let noeuds = vec![
//!     Node::new("apiacees", "apiacees")
//!         .detail("famille")
//!         .on_click(MonMessage::Regarder("apiacees".into()))
//!         .children(vec![Node::new("daucus", "daucus")]),
//! ];
//! tree(noeuds, &ouverts, |cle| MonMessage::Deplier(cle.to_string()))
//! ```
//!
//! # Ou vit l'etat d'ouverture
//!
//! Pas dans l'arbre : chez l'appelant, sous forme d'un ensemble de **cles**
//! ([`Expanded`]). C'est ce qui fait qu'un noeud reste ouvert quand l'arbre est
//! reconstruit — et il l'est a chaque image, puisque `view` repart de zero.
//! Une cle est un chemin stable (`champ:sablons/allee:1`) : elle survit a
//! l'ajout d'un voisin, contrairement a un indice.
//!
//! Un noeud sans enfant n'a pas de chevron et ne se replie pas : montrer une
//! fleche qui n'ouvre rien apprend a ne plus les regarder.

use std::collections::HashSet;
use iced::widget::{button, column, container, row, text};
use iced::{Alignment, Border, Color, Element, Length};
use crate::colors::*;

/// Les cles des noeuds deplies. Vit chez l'appelant, pas dans l'arbre.
pub type Expanded = HashSet<String>;

/// Retrait de chaque niveau, en pixels.
const RETRAIT: f32 = 14.0;

/// Un noeud de l'arbre.
///
/// Se construit en chaine : `Node::new(cle, libelle).detail(..).on_click(..)`.
/// Les champs restent publics — un widget n'a rien a cacher a qui l'utilise.
pub class Node<Message> {
    /// Chemin stable, unique dans l'arbre : c'est lui qui porte l'ouverture.
    pub key: String,
    pub label: String,
    /// A droite, en gris : un compte, une culture, un age.
    pub detail: Option<String>,
    /// Ce que le clic sur la ligne envoie. `None` : la ligne ne fait que
    /// deplier — et alors elle est cliquable en entier, chevron compris.
    pub on_click: Option<Message>,
    /// Vrai si la ligne est celle qu'on regarde.
    pub selected: bool,
    /// Une barre fine sous la ligne, entre 0 et 1 : un calcul en cours.
    ///
    /// Elle est **dans le noeud** et non dans un panneau a part parce que
    /// c'est la que l'oeil est : « il ne se passe rien » a ete dit d'un daemon
    /// qui travaillait depuis dix minutes, dont l'avancement s'affichait tout
    /// en bas de la colonne, loin de l'allee qu'on venait d'importer.
    pub progress: Option<f32>,
    pub children: Vec<Node<Message>>,

    pub fn new(key: impl Into<String>, label: impl Into<String>) -> Self {
        Self {
            key: key.into(),
            label: label.into(),
            detail: None,
            on_click: None,
            selected: false,
            progress: None,
            children: Vec::new(),
        }
    }

    pub fn detail(mut self, d: impl Into<String>) -> Self {
        self.detail = Some(d.into());
        self
    }

    /// Ce que le clic sur la ligne envoie.
    pub fn on_click(mut self, m: Message) -> Self {
        self.on_click = Some(m);
        self
    }

    /// Marque la ligne qu'on regarde.
    pub fn selected(mut self, oui: bool) -> Self {
        self.selected = oui;
        self
    }

    /// Une barre de progression sous la ligne. `None` : aucune.
    pub fn progress(mut self, p: Option<f32>) -> Self {
        self.progress = p;
        self
    }

    pub fn children(mut self, e: Vec<Node<Message>>) -> Self {
        self.children = e;
        self
    }
}

/// L'arbre entier, a plat dans une colonne.
///
/// `bascule` dit **ce que deplier veut dire pour cet arbre-la** : on l'appelle
/// avec la cle du noeud, elle rend le message a envoyer. Un seul argument a
/// l'appel plutot qu'un champ sur chaque noeud — et surtout, il est
/// impossible de l'oublier.
///
/// C'est la correction d'un defaut trouve a l'ecran : le chevron etait cable
/// sur un message d'une application precise, donc le `+` d'un second arbre
/// depliait le premier, **en silence**.
pub fn tree<'a, Message: Clone + 'a>(
    noeuds: Vec<Node<Message>>,
    ouverts: &Expanded,
    bascule: impl Fn(&str) -> Message,
) -> Element<'a, Message> {
    let mut lignes = Vec::new();
    for n in noeuds {
        empiler(&mut lignes, n, ouverts, 0, &bascule);
    }
    column(lignes).spacing(1).into()
}

/// Aplatit le sous-arbre en lignes, en n'y faisant descendre que ce qui est
/// ouvert : un arbre profond ne coute rien tant qu'il est replie.
fn empiler<'a, Message: Clone + 'a>(
    lignes: &mut Vec<Element<'a, Message>>,
    n: Node<Message>,
    ouverts: &Expanded,
    niveau: u16,
    bascule: &impl Fn(&str) -> Message,
) {
    let ouvert = ouverts.contains(&n.key);
    let a_des_enfants = !n.children.is_empty();
    lignes.push(ligne(&n, ouvert, a_des_enfants, niveau, bascule));
    if ouvert {
        for enfant in n.children {
            empiler(lignes, enfant, ouverts, niveau + 1, bascule);
        }
    }
}

/// Ce que la ligne envoie, et ce que le chevron envoie.
///
/// Extrait de la construction du widget **parce que c'est la seule partie qui
/// peut etre fausse en silence**, et qu'elle l'a ete : le chevron etait cable
/// sur le message d'une application, donc le `+` d'un autre arbre depliait le
/// sien. Rien ne bougeait, rien ne se plaignait.
fn messages<Message: Clone>(
    n: &Node<Message>,
    a_des_enfants: bool,
    bascule: &impl Fn(&str) -> Message,
) -> (Option<Message>, Message) {
    let chevron = bascule(&n.key);
    // Sans action propre, le clic vaut pour toute la ligne : viser un chevron
    // de 12 pixels a la souris est une corvee. Sans enfant NI action, la ligne
    // n'envoie rien — `None`, et le bouton reste inerte.
    let ligne = match (&n.on_click, a_des_enfants) {
        (Some(m), _) => Some(m.clone()),
        (None, true) => Some(chevron.clone()),
        (None, false) => None,
    };
    (ligne, chevron)
}

fn ligne<'a, Message: Clone + 'a>(
    n: &Node<Message>,
    ouvert: bool,
    a_des_enfants: bool,
    niveau: u16,
    bascule: &impl Fn(&str) -> Message,
) -> Element<'a, Message> {
    // `+` / `-` et pas des triangles : la police d'iced n'a pas les chevrons
    // pleins, qui sortaient en carres vides — vu a l'ecran. Le signe est de
    // toute facon la convention la plus lue pour deplier.
    let chevron = if a_des_enfants {
        if ouvert { "-" } else { "+" }
    } else {
        // Un espace, pas rien : sans lui, les libelles des feuilles ne
        // s'alignent pas sur ceux de leurs voisins repliables.
        " "
    };
    let choisi = n.selected;
    // Un noeud qui a une action **et** des enfants a deux gestes a offrir :
    // le chevron deplie, le reste de la ligne agit. C'est la convention de
    // tous les explorateurs de fichiers, et c'est le seul cas ou l'on renonce
    // a la ligne entiere cliquable.
    let chevron_separe = n.on_click.is_some() && a_des_enfants;
    let (msg_ligne, msg_chevron) = messages(n, a_des_enfants, bascule);

    let mut contenu = row![].spacing(2).align_y(Alignment::Center);
    if !chevron_separe {
        contenu = contenu.push(text(chevron).size(11).color(TEXT_SECONDARY).width(12));
    }
    contenu = contenu.push(
        text(n.label.clone())
            .size(12)
            .color(if choisi { Color::WHITE } else { TEXT }),
    );
    if let Some(d) = &n.detail {
        contenu = contenu
            .push(iced::widget::Space::with_width(Length::Fill))
            .push(text(d.clone()).size(11).color(TEXT_SECONDARY));
    }

    let mut bouton = button(contenu)
        .padding([3, 6])
        .width(Length::Fill)
        .style(move |_theme, statut| {
            let fond = if choisi {
                SELECTION
            } else {
                match statut {
                    button::Status::Hovered => Color::from_rgb(0.22, 0.22, 0.22),
                    _ => Color::TRANSPARENT,
                }
            };
            button::Style {
                background: Some(fond.into()),
                text_color: Color::WHITE,
                border: Border {
                    radius: 3.0.into(),
                    ..Default::default()
                },
                ..Default::default()
            }
        });
    if let Some(m) = msg_ligne {
        bouton = bouton.on_press(m);
    }

    let corps: Element<'a, Message> = if chevron_separe {
        // Le chevron sort de la ligne : il devient sa propre cible.
        row![
            button(text(chevron).size(11).color(TEXT_SECONDARY))
                .padding([3, 2])
                .style(|_theme, statut| button::Style {
                    background: match statut {
                        button::Status::Hovered => Some(Color::from_rgb(0.22, 0.22, 0.22).into()),
                        _ => None,
                    },
                    text_color: Color::WHITE,
                    border: Border {
                        radius: 3.0.into(),
                        ..Default::default()
                    },
                    ..Default::default()
                })
                .on_press(msg_chevron),
            bouton,
        ]
        .spacing(2)
        .align_y(Alignment::Center)
        .into()
    } else {
        bouton.into()
    };

    // La barre passe **sous** la ligne, pleine largeur : elle ne dispute pas
    // sa place au libelle ni au detail, et elle se lit d'un coup d'oeil sans
    // qu'on ait a la chercher.
    let corps: Element<'a, Message> = match n.progress {
        Some(p) => column![
            corps,
            // Style explicite : a zero, la barre par defaut est une piste
            // sombre sur fond sombre — invisible, donc prise pour une barre en
            // panne. La piste doit se voir **avant** que le calcul n'avance,
            // c'est tout l'interet de l'afficher des le depot.
            iced::widget::progress_bar(0.0..=1.0, p.clamp(0.0, 1.0))
                .height(4)
                .style(|_theme| iced::widget::progress_bar::Style {
                    background: Color::from_rgb(0.30, 0.30, 0.30).into(),
                    bar: GREEN.into(),
                    border: Border {
                        radius: 2.0.into(),
                        ..Default::default()
                    },
                })
        ]
        .spacing(2)
        .into(),
        None => corps,
    };

    container(corps)
        .padding(iced::Padding {
            left: niveau as f32 * RETRAIT,
            ..iced::Padding::ZERO
        })
        .into()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Un message d'essai : le widget n'en connait aucun, donc le test se
    /// donne le sien. C'est la preuve que la genericite tient.
    #[derive(Debug, Clone, PartialEq)]
    enum Essai {
        Deplier(String),
        Regarder(String),
    }

    fn feuille(cle: &str) -> Node<Essai> {
        Node::new(cle, cle)
    }

    fn deplier(cle: &str) -> Essai {
        Essai::Deplier(cle.to_string())
    }

    /// **Le chevron doit deplier l'arbre qu'on regarde, pas un autre.**
    ///
    /// Avant que `bascule` ne soit un parametre, le chevron envoyait le
    /// message d'une application precise : le `+` d'un second arbre depliait
    /// donc le premier, absent de l'ecran. Un clic sans effet et sans erreur.
    #[test]
    fn le_chevron_envoie_toujours_la_bascule_de_son_arbre() {
        let n = feuille("apiacees").children(vec![feuille("daucus")]);

        // Sans action propre : la ligne entiere deplie, chevron compris.
        let (ligne, chevron) = messages(&n, true, &deplier);
        assert_eq!(chevron, Essai::Deplier("apiacees".into()));
        assert_eq!(ligne, Some(Essai::Deplier("apiacees".into())));

        // Avec : la ligne agit, le chevron deplie. Deux gestes distincts.
        let n = n.on_click(Essai::Regarder("apiacees".into()));
        let (ligne, chevron) = messages(&n, true, &deplier);
        assert_eq!(chevron, Essai::Deplier("apiacees".into()));
        assert_eq!(ligne, Some(Essai::Regarder("apiacees".into())));

        // Une feuille sans action n'envoie RIEN : un clic qui n'ouvre rien ne
        // doit pas non plus faire semblant.
        let (ligne, _) = messages(&feuille("nantaise"), false, &deplier);
        assert_eq!(ligne, None);
    }

    /// Une cle est un chemin : elle doit survivre a l'arrivee d'un voisin,
    /// ce qu'un indice ne ferait pas.
    #[test]
    fn les_cles_sont_des_chemins_stables() {
        let a = Node::<Essai>::new("champ:sablons", "Les Sablons")
            .children(vec![feuille("champ:sablons/allee:1")]);
        assert_eq!(a.children[0].key, "champ:sablons/allee:1");
        // Un voisin insere avant ne change pas la cle du noeud existant.
        let b = Node::<Essai>::new("champ:sablons", "Les Sablons").children(vec![
            feuille("champ:sablons/allee:0"),
            feuille("champ:sablons/allee:1"),
        ]);
        assert_eq!(b.children[1].key, a.children[0].key);
    }

    /// Ce qui est replie n'est pas parcouru : un arbre profond ne coute que
    /// ce qu'on en a ouvert.
    #[test]
    fn un_sous_arbre_replie_ne_produit_aucune_ligne() {
        let racine = feuille("a").children(vec![feuille("b").children(vec![feuille("c")])]);
        let mut lignes = Vec::new();
        empiler(&mut lignes, racine, &Expanded::new(), 0, &deplier);
        assert_eq!(lignes.len(), 1, "seule la racine est rendue");

        let racine = feuille("a").children(vec![feuille("b").children(vec![feuille("c")])]);
        let ouverts: Expanded = ["a".to_string()].into_iter().collect();
        let mut lignes = Vec::new();
        empiler(&mut lignes, racine, &ouverts, 0, &deplier);
        assert_eq!(lignes.len(), 2, "« a » ouvert montre « b », pas « c »");
    }
}
