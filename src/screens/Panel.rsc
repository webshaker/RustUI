//! Ce qu'une fonction de remplissage peut mettre dans un panneau, et dans la
//! barre de menus. Chaque bouton est relie directement a une action
//! `|doc| ...` qui modifie les donnees : RustUI se charge du reste.
//!
//! ```ignore
//! fn panneau(_ecran: &str, p: &mut Panel<Document>, doc: &Document) {
//!     p.add_section("Sélection");
//!     p.add_line("Valeur", doc.valeur.clone());
//!     p.add_row(|r| {
//!         r.add_button("Pause", Document::pause).small();
//!         r.add_text("EN PAUSE").color(rust_ui::ORANGE);
//!     });
//! }
//! ```

use std::cell::RefCell;
use std::sync::Arc;

use iced::widget::{Space, column, container, row, scrollable};
use iced::{Border, Color, Element, Length};

use crate::colors::*;
use crate::tree::{Expanded, Node};
import { Button, CheckBox, Input, Text } from "./items.rsc";

/// Ce qu'un element de l'ecran peut demander au moteur.
#[derive(Debug, Clone)]
pub enum Msg {
    Action(usize),
    Text(usize, String),
    Toggle(usize, bool),
    /// Un evenement d'un widget (`Panel::add_widget`), pour l'action `usize`.
    Event(usize, Payload),
    Show(&'static str),
    OpenMenu(usize),
    OpenSubmenu(usize),
    CloseMenus,
    Key(iced::keyboard::Key, iced::keyboard::Modifiers),
    Fichier(u64, Option<std::path::PathBuf>),
    Timer(usize),
    Fermeture,
    Ancien(Payload),
    Rien,
    Quit,
}

/// Une valeur de type quelconque, portee par un `Msg` (evenement d'un widget,
/// `Message` d'une interface d'avant).
#[derive(Clone)]
pub struct Payload(pub(crate) Arc<dyn std::any::Any + Send + Sync>);

impl std::fmt::Debug for Payload {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("Payload")
    }
}

/// Une action enregistree pendant l'affichage, appelee au clic.
pub(crate) type SurTexte<D> = Box<dyn Fn(&mut D, String)>;
pub(crate) type SurCase<D> = Box<dyn Fn(&mut D, bool)>;
pub(crate) type SurEvenement<D> = Box<dyn Fn(&mut D, &Payload)>;

pub(crate) enum Action<D> {
    Simple(Box<dyn Fn(&mut D)>),
    Text(SurTexte<D>),
    Toggle(SurCase<D>),
    Event(SurEvenement<D>),
}

/// Les actions de l'affichage en cours (refaites a chaque affichage).
pub(crate) type Actions<D> = RefCell<Vec<Action<D>>>;

pub(crate) fn enregistrer<D>(actions: &Actions<D>, a: Action<D>) -> usize {
    let mut v = actions.borrow_mut();
    v.push(a);
    v.len() - 1
}

/// Un element du panneau, change en widget a la fin du remplissage.
pub(crate) enum Item<'a, D> {
    Text(Text),
    Line(String, Text),
    Button(Button),
    Input(Input),
    Check(CheckBox),
    Group(Group<'a, D>),
    Element(Element<'a, Msg>),
}

impl<'a, D> Item<'a, D> {
    fn view(self) -> Element<'a, Msg> {
        match self {
            Item::Text(t) => t.view(),
            Item::Line(libelle, valeur) => row![
                iced::widget::text(libelle).size(12).color(TEXT_SECONDARY).width(95),
                container(valeur.view()).width(Length::Fill),
            ]
            .spacing(6)
            .width(Length::Fill)
            .into(),
            Item::Button(b) => b.view(),
            Item::Input(i) => i.view(),
            Item::Check(c) => c.view(),
            Item::Group(g) => g.view(),
            Item::Element(e) => e,
        }
    }
}

/// La marge d'un contenu qui defile : la barre de defilement passe par-dessus
/// son bord droit, qui ne doit donc rien porter.
fn a_droite([vertical, horizontal]: [u16; 2]) -> iced::Padding {
    iced::Padding { top: vertical as f32, bottom: vertical as f32, left: horizontal as f32, right: horizontal as f32 + 10.0 }
}

/// Un clic d'arbre : deplier un noeud, ou l'action de sa ligne.
#[derive(Clone)]
enum Arbre<K> {
    Deplier(String),
    Clic(K),
}

fn noeud_d_arbre<K>(n: Node<K>) -> Node<Arbre<K>> {
    Node {
        key: n.key,
        label: n.label,
        detail: n.detail,
        on_click: n.on_click.map(Arbre::Clic),
        selected: n.selected,
        progress: n.progress,
        children: n.children.into_iter().map(noeud_d_arbre).collect(),
    }
}

/// Un panneau en cours de remplissage.
pub class Panel<'a, D> {
    pub(crate) items: Vec<Item<'a, D>>,
    pub(crate) actions: &'a Actions<D>,
    /// Barre d'outils, ligne : elements cote a cote.
    pub(crate) horizontal: bool,
    pub(crate) marge: Option<u16>,
    pub(crate) espacement: Option<u16>,
    pub(crate) largeur: Option<f32>,
    pub(crate) hauteur: Option<f32>,
    pub(crate) cache: bool,
    pub(crate) defile: bool,
    pub(crate) fond: Option<Color>,
    pub(crate) centre: bool,

    pub(crate) fn new(actions: &'a Actions<D>, horizontal: bool) -> Self {
        Self { items: vec![], actions, horizontal, marge: None, espacement: None, largeur: None, hauteur: None, cache: false, defile: false, fond: None, centre: false }
    }

    fn texte(&mut self, t: Text) -> &mut Text {
        self.items.push(Item::Text(t));
        match self.items.last_mut() {
            Some(Item::Text(t)) => t,
            _ => unreachable!(),
        }
    }

    /// Un texte.
    pub fn add_text(&mut self, t: impl Into<String>) -> &mut Text {
        self.texte(Text::new(t.into(), 13, TEXT))
    }

    /// Un titre.
    pub fn add_title(&mut self, t: impl Into<String>) -> &mut Text {
        self.texte(Text::new(t.into(), 16, TEXT))
    }

    /// L'en-tete d'une section (petit, gris).
    pub fn add_section(&mut self, t: impl Into<String>) -> &mut Text {
        self.texte(Text::new(t.into(), 13, TEXT_SECONDARY))
    }

    /// Un texte discret (aide, remarque).
    pub fn add_note(&mut self, t: impl Into<String>) -> &mut Text {
        self.texte(Text::new(t.into(), 12, TEXT_SECONDARY))
    }

    /// Une ligne « libelle   valeur », les libelles alignes en colonne ;
    /// la valeur se regle ensuite (`.color(...)`).
    pub fn add_line(&mut self, label: impl Into<String>, value: impl Into<String>) -> &mut Text {
        self.items.push(Item::Line(label.into(), Text::new(value.into(), 12, TEXT)));
        match self.items.last_mut() {
            Some(Item::Line(_, t)) => t,
            _ => unreachable!(),
        }
    }

    fn bouton(&mut self, b: Button) -> &mut Button {
        self.items.push(Item::Button(b));
        match self.items.last_mut() {
            Some(Item::Button(b)) => b,
            _ => unreachable!(),
        }
    }

    /// Un bouton ; `action` modifie les donnees au clic.
    pub fn add_button(&mut self, label: impl Into<String>, action: impl Fn(&mut D) + 'static) -> &mut Button {
        let i = enregistrer(self.actions, Action::Simple(Box::new(action)));
        self.bouton(Button::new(label.into(), Some(Msg::Action(i))))
    }

    /// Un bouton grise quand `enabled` est faux.
    pub fn add_button_if(&mut self, label: impl Into<String>, enabled: bool, action: impl Fn(&mut D) + 'static) -> &mut Button {
        self.add_button(label, action).enabled(enabled)
    }

    /// Un bouton qui affiche un autre ecran.
    pub fn add_screen_button(&mut self, label: impl Into<String>, screen: &'static str) -> &mut Button {
        self.bouton(Button::new(label.into(), Some(Msg::Show(screen))))
    }

    /// Un champ de saisie ; `on_change` recoit le texte a chaque frappe.
    pub fn add_input(&mut self, placeholder: &str, value: &str, on_change: impl Fn(&mut D, String) + 'static) -> &mut Input {
        let i = enregistrer(self.actions, Action::Text(Box::new(on_change)));
        self.items.push(Item::Input(Input { placeholder: placeholder.into(), value: value.into(), action: i, width: None, size: 13 }));
        match self.items.last_mut() {
            Some(Item::Input(t)) => t,
            _ => unreachable!(),
        }
    }

    /// Une case a cocher ; `on_toggle` recoit le nouvel etat.
    pub fn add_checkbox(&mut self, label: impl Into<String>, checked: bool, on_toggle: impl Fn(&mut D, bool) + 'static) -> &mut CheckBox {
        let i = enregistrer(self.actions, Action::Toggle(Box::new(on_toggle)));
        self.items.push(Item::Check(CheckBox { label: label.into(), checked, action: i, text_size: 13 }));
        match self.items.last_mut() {
            Some(Item::Check(c)) => c,
            _ => unreachable!(),
        }
    }

    /// Un curseur sur `range` ; `on_change` recoit la nouvelle valeur.
    pub fn add_slider(&mut self, range: std::ops::RangeInclusive<f32>, value: f32, on_change: impl Fn(&mut D, f32) + 'static) {
        self.add_widget(iced::widget::slider(range, value, |v| v), on_change);
    }

    /// Un trait de separation.
    pub fn add_separator(&mut self) {
        self.items.push(Item::Element(if self.horizontal { crate::vertical_separator() } else { crate::horizontal_separator() }));
    }

    /// Un espace qui pousse la suite au bout (a droite, ou en bas).
    pub fn add_space(&mut self) {
        self.items.push(Item::Element(if self.horizontal { Space::with_width(Length::Fill).into() } else { Space::with_height(Length::Fill).into() }));
    }

    /// Un espace fixe, en pixels.
    pub fn add_gap(&mut self, pixels: f32) {
        self.items.push(Item::Element(if self.horizontal { Space::with_width(pixels).into() } else { Space::with_height(pixels).into() }));
    }

    /// Un petit carre de couleur (legende).
    pub fn add_swatch(&mut self, color: Color) {
        let carre = container(Space::new(10, 10)).style(move |_| container::Style { background: Some(color.into()), ..Default::default() });
        self.items.push(Item::Element(carre.into()));
    }

    fn groupe(&mut self, horizontal: bool, defile: bool, fill: impl FnOnce(&mut Panel<'a, D>)) -> &mut Group<'a, D> {
        let mut p = Panel::new(self.actions, horizontal);
        fill(&mut p);
        self.items.push(Item::Group(Group { panel: p, fond: None, bordure: None, marge: 0, defile, en_bas: false }));
        match self.items.last_mut() {
            Some(Item::Group(g)) => g,
            _ => unreachable!(),
        }
    }

    /// Des elements cote a cote ; `fill` les ajoute.
    pub fn add_row(&mut self, fill: impl FnOnce(&mut Panel<'a, D>)) -> &mut Group<'a, D> {
        self.groupe(true, false, fill)
    }

    /// Des elements l'un sous l'autre, regroupes (un cadre, un espacement a part).
    pub fn add_column(&mut self, fill: impl FnOnce(&mut Panel<'a, D>)) -> &mut Group<'a, D> {
        self.groupe(false, false, fill)
    }

    /// Une zone qui defile, dans la hauteur restante.
    pub fn add_scroll(&mut self, fill: impl FnOnce(&mut Panel<'a, D>)) -> &mut Group<'a, D> {
        self.groupe(false, true, fill)
    }

    /// Un arbre repliable. `expanded` : les cles des noeuds ouverts ;
    /// `on_toggle` recoit la cle d'un noeud a ouvrir ou fermer, `on_click`
    /// la valeur donnee a `Node::on_click`.
    pub fn add_tree<K: Clone + Send + Sync + 'static>(
        &mut self,
        nodes: Vec<Node<K>>,
        expanded: &Expanded,
        on_toggle: impl Fn(&mut D, String) + 'static,
        on_click: impl Fn(&mut D, K) + 'static,
    ) {
        let noeuds = nodes.into_iter().map(noeud_d_arbre).collect();
        let arbre = crate::tree(noeuds, expanded, |cle| Arbre::Deplier(cle.to_string()));
        self.add_widget(arbre, move |d, a| match a {
            Arbre::Deplier(cle) => on_toggle(d, cle),
            Arbre::Clic(k) => on_click(d, k),
        });
    }

    /// Un widget qui produit ses propres evenements (`E`) : `on_event` les
    /// recoit. Pour un widget de RustUI qui n'a pas sa methode ici (l'editeur
    /// de code, une courbe...).
    pub fn add_widget<E: Clone + Send + Sync + 'static>(&mut self, element: impl Into<Element<'a, E>>, on_event: impl Fn(&mut D, E) + 'static) {
        let i = enregistrer(
            self.actions,
            Action::Event(Box::new(move |d, p: &Payload| {
                if let Some(e) = p.0.downcast_ref::<E>() {
                    on_event(d, e.clone());
                }
            })),
        );
        self.items.push(Item::Element(element.into().map(move |e| Msg::Event(i, Payload(Arc::new(e))))));
    }

    /// Un dessin (`canvas::Program`) qui occupe toute la place ; ses
    /// evenements (`E` : souris, clavier...) vont a `on_event`.
    #[cfg(feature = "canvas")]
    pub fn add_canvas<E: Clone + Send + Sync + 'static>(&mut self, program: impl iced::widget::canvas::Program<E> + 'a, on_event: impl Fn(&mut D, E) + 'static) {
        // Le calque rogne le dessin a sa place (un canvas iced deborde sinon).
        let dessin = crate::layer(iced::widget::canvas(program).width(Length::Fill).height(Length::Fill));
        self.add_widget(dessin, on_event);
    }

    /// Une courbe, sur `height` pixels de haut.
    #[cfg(feature = "canvas")]
    pub fn add_curve(&mut self, curve: crate::Curve, height: f32) {
        self.items.push(Item::Element(curve.view(height)));
    }

    /// Passerelle de migration : un element de l'interface a `Message`, dont les
    /// messages vont au gestionnaire declare par `Window::legacy`.
    pub fn add_legacy<M: Send + Sync + 'static>(&mut self, element: impl Into<Element<'a, M>>) {
        self.items.push(Item::Element(element.into().map(|m| Msg::Ancien(Payload(Arc::new(m))))));
    }

    /// Marge interieure du panneau, en pixels (0 : le contenu touche les bords).
    pub fn set_padding(&mut self, pixels: u16) {
        self.marge = Some(pixels);
    }

    /// Ecart entre les elements, en pixels.
    pub fn set_spacing(&mut self, pixels: u16) {
        self.espacement = Some(pixels);
    }

    /// Largeur fixe du panneau, en pixels (dans un `Splitter`, au lieu de sa part).
    pub fn set_width(&mut self, pixels: f32) {
        self.largeur = Some(pixels);
    }

    /// Hauteur fixe du panneau, en pixels.
    pub fn set_height(&mut self, pixels: f32) {
        self.hauteur = Some(pixels);
    }

    /// Le panneau n'est pas affiche (sa place revient aux autres).
    pub fn hide(&mut self) {
        self.cache = true;
    }

    /// Tout le panneau defile.
    pub fn set_scroll(&mut self) {
        self.defile = true;
    }

    pub fn set_background(&mut self, color: Color) {
        self.fond = Some(color);
    }

    /// Le contenu au milieu du panneau.
    pub fn set_centered(&mut self) {
        self.centre = true;
    }

    /// Les elements, en ligne ou en colonne ; une colonne `large` prend toute la largeur.
    pub(crate) fn contenu(self, large: bool) -> Element<'a, Msg> {
        let horizontal = self.horizontal;
        let espacement = self.espacement.unwrap_or(8);
        let centre = self.centre;
        let items: Vec<Element<'a, Msg>> = self.items.into_iter().map(Item::view).collect();
        if horizontal {
            row(items).spacing(espacement).align_y(iced::Alignment::Center).into()
        } else if centre {
            column(items).spacing(espacement).align_x(iced::Alignment::Center).into()
        } else if large {
            column(items).spacing(espacement).width(Length::Fill).into()
        } else {
            column(items).spacing(espacement).into()
        }
    }

    /// Le contenu seul, sans fond ni marges (pour une modale).
    pub(crate) fn into_content(mut self) -> Element<'a, Msg> {
        self.espacement = Some(self.espacement.unwrap_or(12));
        self.contenu(true)
    }

    pub(crate) fn into_element(self, background: Color) -> Element<'a, Msg> {
        let horizontal = self.horizontal;
        let marge = match self.marge {
            Some(m) => [m, m],
            None if horizontal => [4, 8],
            None => [10, 10],
        };
        let fond = self.fond.unwrap_or(background);
        let (defile, centre, largeur, hauteur) = (self.defile, self.centre, self.largeur, self.hauteur);
        let contenu = self.contenu(true);
        let mut boite = if defile {
            container(scrollable(container(contenu).padding(a_droite(marge)).width(Length::Fill)).height(Length::Fill).width(Length::Fill))
        } else {
            container(contenu).padding(marge)
        };
        boite = boite
            .width(largeur.map(Length::Fixed).unwrap_or(Length::Fill))
            .height(hauteur.map(Length::Fixed).unwrap_or(if horizontal { Length::Shrink } else { Length::Fill }))
            .style(move |_| container::Style { background: Some(fond.into()), ..Default::default() });
        if centre {
            boite = boite.center_x(Length::Fill).center_y(Length::Fill);
        }
        boite.into()
    }
}

/// Un groupe d'elements (ligne, colonne, zone qui defile), a regler ensuite.
pub class Group<'a, D> {
    pub(crate) panel: Panel<'a, D>,
    pub(crate) fond: Option<Color>,
    pub(crate) bordure: Option<Color>,
    pub(crate) marge: u16,
    pub(crate) defile: bool,
    pub(crate) en_bas: bool,

    pub fn background(&mut self, color: Color) -> &mut Self {
        self.fond = Some(color);
        self
    }

    /// Un cadre de cette couleur.
    pub fn border(&mut self, color: Color) -> &mut Self {
        self.bordure = Some(color);
        self
    }

    /// Marge interieure, en pixels.
    pub fn padding(&mut self, pixels: u16) -> &mut Self {
        self.marge = pixels;
        self
    }

    /// Ecart entre les elements, en pixels.
    pub fn spacing(&mut self, pixels: u16) -> &mut Self {
        self.panel.espacement = Some(pixels);
        self
    }

    /// Une zone qui defile reste collee en bas (un journal qui s'allonge).
    pub fn from_bottom(&mut self) -> &mut Self {
        self.en_bas = true;
        self
    }

    pub(crate) fn view(self) -> Element<'a, Msg> {
        let (fond, bordure, marge, defile, en_bas) = (self.fond, self.bordure, self.marge, self.defile, self.en_bas);
        let horizontal = self.panel.horizontal;
        // Un groupe a la taille de son contenu, sauf encadre ou defilant : toute la largeur.
        let large = defile || fond.is_some() || bordure.is_some();
        let contenu = self.panel.contenu(large);
        let contenu: Element<'a, Msg> = if defile {
            let s = scrollable(container(contenu).padding(a_droite([0, 0]))).width(Length::Fill).height(Length::Fill);
            if en_bas { s.anchor_bottom().into() } else { s.into() }
        } else {
            contenu
        };
        let mut boite = container(contenu).padding(marge);
        if large && !horizontal || defile {
            boite = boite.width(Length::Fill);
        }
        if defile {
            boite = boite.height(Length::Fill);
        }
        if fond.is_some() || bordure.is_some() {
            boite = boite.style(move |_| container::Style {
                background: fond.map(Into::into),
                border: Border { color: bordure.unwrap_or(Color::TRANSPARENT), width: if bordure.is_some() { 1.0 } else { 0.0 }, radius: 4.0.into() },
                ..Default::default()
            });
        }
        boite.into()
    }
}

/// La barre de menus en cours de remplissage.
pub class MenuBar<'a, D> {
    pub(crate) menus: Vec<crate::Menu<Msg>>,
    pub(crate) actions: &'a Actions<D>,

    pub(crate) fn new(actions: &'a Actions<D>) -> Self {
        Self { menus: vec![], actions }
    }

    /// Un menu de la barre ; on y ajoute ses entrees a la suite.
    pub fn menu(&mut self, label: impl Into<std::borrow::Cow<'static, str>>) -> MenuBuilder<'_, 'a, D> {
        self.menus.push(crate::Menu::new(label, vec![]));
        MenuBuilder { bar: self }
    }
}

/// Les entrees d'un menu.
pub class MenuBuilder<'b, 'a, D> {
    pub(crate) bar: &'b mut MenuBar<'a, D>,

    fn pousser(&mut self, item: crate::MenuItem<Msg>) {
        self.bar.menus.last_mut().unwrap().items.push(item);
    }

    /// Une entree ; `action` modifie les donnees.
    pub fn item(mut self, label: impl Into<std::borrow::Cow<'static, str>>, action: impl Fn(&mut D) + 'static) -> Self {
        let i = enregistrer(self.bar.actions, Action::Simple(Box::new(action)));
        self.pousser(crate::MenuItem::new(label, Msg::Action(i)));
        self
    }

    /// Une entree grisee quand `enabled` est faux.
    pub fn item_if(mut self, label: impl Into<std::borrow::Cow<'static, str>>, enabled: bool, action: impl Fn(&mut D) + 'static) -> Self {
        let i = enregistrer(self.bar.actions, Action::Simple(Box::new(action)));
        self.pousser(crate::MenuItem::when(label, enabled, Msg::Action(i)));
        self
    }

    /// Un sous-menu, ouvert a droite au survol ; `fill` y ajoute ses entrees.
    pub fn submenu(mut self, label: impl Into<std::borrow::Cow<'static, str>>, fill: impl FnOnce(&mut SubMenu<'a, D>)) -> Self {
        let mut s = SubMenu { items: vec![], actions: self.bar.actions };
        fill(&mut s);
        self.pousser(crate::MenuItem::submenu(label, s.items));
        self
    }

    /// Une entree qui affiche un autre ecran.
    pub fn screen_item(mut self, label: impl Into<std::borrow::Cow<'static, str>>, screen: &'static str) -> Self {
        self.pousser(crate::MenuItem::new(label, Msg::Show(screen)));
        self
    }

    /// Une entree qui ferme l'application.
    pub fn quit_item(mut self, label: impl Into<std::borrow::Cow<'static, str>>) -> Self {
        self.pousser(crate::MenuItem::new(label, Msg::Quit));
        self
    }
}

/// Les entrees d'un sous-menu.
pub class SubMenu<'a, D> {
    pub(crate) items: Vec<crate::MenuItem<Msg>>,
    pub(crate) actions: &'a Actions<D>,

    /// Une entree ; `action` modifie les donnees.
    pub fn item(&mut self, label: impl Into<std::borrow::Cow<'static, str>>, action: impl Fn(&mut D) + 'static) {
        let i = enregistrer(self.actions, Action::Simple(Box::new(action)));
        self.items.push(crate::MenuItem::new(label, Msg::Action(i)));
    }

    /// Une entree grisee quand `enabled` est faux.
    pub fn item_if(&mut self, label: impl Into<std::borrow::Cow<'static, str>>, enabled: bool, action: impl Fn(&mut D) + 'static) {
        let i = enregistrer(self.actions, Action::Simple(Box::new(action)));
        self.items.push(crate::MenuItem::when(label, enabled, Msg::Action(i)));
    }
}
