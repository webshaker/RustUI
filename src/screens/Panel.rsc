//! Ce qu'une fonction de remplissage peut mettre dans un panneau, et dans la
//! barre de menus. Chaque bouton est relie directement a une action
//! `|doc| ...` qui modifie les donnees : RustUI se charge du reste.

use std::cell::RefCell;

use iced::widget::{Space, button, checkbox, column, container, row, text, text_input};
use iced::{Element, Length};

use crate::colors::*;

/// Ce qu'un element de l'ecran peut demander au moteur.
#[derive(Debug, Clone)]
pub enum Msg {
    Action(usize),
    Text(usize, String),
    Toggle(usize, bool),
    Show(&'static str),
    OpenMenu(usize),
    CloseMenus,
    Key(iced::keyboard::Key, iced::keyboard::Modifiers),
    Quit,
}

/// Une action enregistree pendant l'affichage, appelee au clic.
pub(crate) type SurTexte<D> = Box<dyn Fn(&mut D, String)>;
pub(crate) type SurCase<D> = Box<dyn Fn(&mut D, bool)>;

pub(crate) enum Action<D> {
    Simple(Box<dyn Fn(&mut D)>),
    Text(SurTexte<D>),
    Toggle(SurCase<D>),
}

/// Les actions de l'affichage en cours (refaites a chaque affichage).
pub(crate) type Actions<D> = RefCell<Vec<Action<D>>>;

pub(crate) fn enregistrer<D>(actions: &Actions<D>, a: Action<D>) -> usize {
    let mut v = actions.borrow_mut();
    v.push(a);
    v.len() - 1
}

/// Un panneau en cours de remplissage.
pub class Panel<'a, D> {
    pub(crate) items: Vec<Element<'a, Msg>>,
    pub(crate) actions: &'a Actions<D>,
    /// Barre d'outils : elements cote a cote.
    pub(crate) horizontal: bool,

    pub(crate) fn new(actions: &'a Actions<D>, horizontal: bool) -> Self {
        Self { items: vec![], actions, horizontal }
    }

    /// Un texte.
    pub fn add_text(&mut self, t: impl Into<String>) {
        self.items.push(text(t.into()).size(13).color(TEXT).into());
    }

    /// Un titre de section.
    pub fn add_title(&mut self, t: impl Into<String>) {
        self.items.push(text(t.into()).size(16).color(TEXT).into());
    }

    /// Un texte discret (aide, remarque).
    pub fn add_note(&mut self, t: impl Into<String>) {
        self.items.push(text(t.into()).size(12).color(TEXT_SECONDARY).into());
    }

    /// Un bouton ; `action` modifie les donnees au clic.
    pub fn add_button(&mut self, label: impl Into<String>, action: impl Fn(&mut D) + 'static) {
        self.add_button_if(label, true, action);
    }

    /// Un bouton grise quand `enabled` est faux.
    pub fn add_button_if(&mut self, label: impl Into<String>, enabled: bool, action: impl Fn(&mut D) + 'static) {
        let i = enregistrer(self.actions, Action::Simple(Box::new(action)));
        let b = button(text(label.into()).size(13));
        self.items.push(if enabled { b.on_press(Msg::Action(i)) } else { b }.into());
    }

    /// Un bouton qui affiche un autre ecran.
    pub fn add_screen_button(&mut self, label: impl Into<String>, screen: &'static str) {
        self.items.push(button(text(label.into()).size(13)).on_press(Msg::Show(screen)).into());
    }

    /// Un champ de saisie ; `on_change` recoit le texte a chaque frappe.
    pub fn add_input(&mut self, placeholder: &str, value: &str, on_change: impl Fn(&mut D, String) + 'static) {
        let i = enregistrer(self.actions, Action::Text(Box::new(on_change)));
        self.items.push(text_input(placeholder, value).size(13).on_input(move |t| Msg::Text(i, t)).into());
    }

    /// Une case a cocher ; `on_toggle` recoit le nouvel etat.
    pub fn add_checkbox(&mut self, label: impl Into<String>, checked: bool, on_toggle: impl Fn(&mut D, bool) + 'static) {
        let i = enregistrer(self.actions, Action::Toggle(Box::new(on_toggle)));
        self.items.push(checkbox(label.into(), checked).size(14).text_size(13).on_toggle(move |v| Msg::Toggle(i, v)).into());
    }

    /// Un trait de separation.
    pub fn add_separator(&mut self) {
        self.items.push(if self.horizontal { crate::vertical_separator() } else { crate::horizontal_separator() });
    }

    /// Un espace qui pousse la suite au bout (a droite, ou en bas).
    pub fn add_space(&mut self) {
        self.items.push(if self.horizontal { Space::with_width(Length::Fill).into() } else { Space::with_height(Length::Fill).into() });
    }

    pub(crate) fn into_element(self, background: iced::Color) -> Element<'a, Msg> {
        let contenu: Element<'a, Msg> = if self.horizontal {
            row(self.items).spacing(8).align_y(iced::Alignment::Center).into()
        } else {
            column(self.items).spacing(8).into()
        };
        container(contenu)
            .padding(if self.horizontal { [4, 8] } else { [10, 10] })
            .width(Length::Fill)
            .height(if self.horizontal { Length::Shrink } else { Length::Fill })
            .style(move |_| container::Style { background: Some(background.into()), ..Default::default() })
            .into()
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
    pub fn menu(&mut self, label: &'static str) -> MenuBuilder<'_, 'a, D> {
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
    pub fn item(mut self, label: &'static str, action: impl Fn(&mut D) + 'static) -> Self {
        let i = enregistrer(self.bar.actions, Action::Simple(Box::new(action)));
        self.pousser(crate::MenuItem::new(label, Msg::Action(i)));
        self
    }

    /// Une entree grisee quand `enabled` est faux.
    pub fn item_if(mut self, label: &'static str, enabled: bool, action: impl Fn(&mut D) + 'static) -> Self {
        let i = enregistrer(self.bar.actions, Action::Simple(Box::new(action)));
        self.pousser(crate::MenuItem::when(label, enabled, Msg::Action(i)));
        self
    }

    /// Une entree qui affiche un autre ecran.
    pub fn screen_item(mut self, label: &'static str, screen: &'static str) -> Self {
        self.pousser(crate::MenuItem::new(label, Msg::Show(screen)));
        self
    }

    /// Une entree qui ferme l'application.
    pub fn quit_item(mut self, label: &'static str) -> Self {
        self.pousser(crate::MenuItem::new(label, Msg::Quit));
        self
    }
}
