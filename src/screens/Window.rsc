//! La fenetre d'une application decrite par ecrans.
//!
//! ```ignore
//! let mut window = Window::new("Mon application", 1600.0, 1000.0);
//! let home = window.add_screen("home");
//! home.add_menu(draw_menu);
//! let split = home.add_splitter(Direction::Horizontal, [1, 2, 1]);
//! split.add_panel(draw_left);
//! window.show("home");
//! window.run(Document::default())
//! ```
//!
//! Les donnees de l'application (`D`, par exemple une classe `Document`) ne
//! sont qu'a un endroit : les fonctions de remplissage les lisent, les actions
//! les modifient. Le moteur graphique (iced) reste cache ici.

use std::cell::RefCell;
use std::rc::Rc;

use iced::keyboard::{self, Key, Modifiers, key::Named};
use iced::widget::{column, stack};
use iced::{Element, Length, Subscription, Task, Theme};

use crate::colors::*;
import { Action, Actions, MenuBar, Msg, Panel } from "./Panel.rsc";
import { Direction, Node, Screen, ScreenDef } from "./Screen.rsc";

/// Une touche de raccourci, lue depuis un texte comme « Ctrl+S » ou « F5 ».
#[derive(Debug, Clone, PartialEq)]
pub(crate) struct Raccourci {
    ctrl: bool,
    shift: bool,
    alt: bool,
    touche: Touche,
}

#[derive(Debug, Clone, PartialEq)]
enum Touche {
    Nommee(Named),
    Caractere(String),
}

impl Raccourci {
    /// « Ctrl+Shift+Z », « F5 », « Delete », « R »...
    fn lire(texte: &str) -> Option<Self> {
        let mut r = Raccourci { ctrl: false, shift: false, alt: false, touche: Touche::Caractere(String::new()) };
        for partie in texte.split('+').map(str::trim) {
            match partie.to_lowercase().as_str() {
                "ctrl" | "control" => r.ctrl = true,
                "shift" | "maj" => r.shift = true,
                "alt" => r.alt = true,
                p => {
                    r.touche = match p {
                        "escape" | "echap" | "esc" => Touche::Nommee(Named::Escape),
                        "delete" | "suppr" => Touche::Nommee(Named::Delete),
                        "enter" | "entree" => Touche::Nommee(Named::Enter),
                        "tab" => Touche::Nommee(Named::Tab),
                        "space" | "espace" => Touche::Nommee(Named::Space),
                        "home" | "origine" => Touche::Nommee(Named::Home),
                        "end" | "fin" => Touche::Nommee(Named::End),
                        "backspace" => Touche::Nommee(Named::Backspace),
                        "up" => Touche::Nommee(Named::ArrowUp),
                        "down" => Touche::Nommee(Named::ArrowDown),
                        "left" => Touche::Nommee(Named::ArrowLeft),
                        "right" => Touche::Nommee(Named::ArrowRight),
                        f if f.starts_with('f') && f.len() > 1 => match f[1..].parse::<u8>().ok()? {
                            1 => Touche::Nommee(Named::F1),
                            2 => Touche::Nommee(Named::F2),
                            3 => Touche::Nommee(Named::F3),
                            4 => Touche::Nommee(Named::F4),
                            5 => Touche::Nommee(Named::F5),
                            6 => Touche::Nommee(Named::F6),
                            7 => Touche::Nommee(Named::F7),
                            8 => Touche::Nommee(Named::F8),
                            9 => Touche::Nommee(Named::F9),
                            10 => Touche::Nommee(Named::F10),
                            11 => Touche::Nommee(Named::F11),
                            12 => Touche::Nommee(Named::F12),
                            _ => return None,
                        },
                        c if c.chars().count() == 1 => Touche::Caractere(c.to_string()),
                        _ => return None,
                    }
                }
            }
        }
        Some(r)
    }

    fn correspond(&self, touche: &Key, m: Modifiers) -> bool {
        if m.control() != self.ctrl || m.shift() != self.shift || m.alt() != self.alt {
            return false;
        }
        match (&self.touche, touche.as_ref()) {
            (Touche::Nommee(n), Key::Named(k)) => *n == k,
            (Touche::Caractere(c), Key::Character(k)) => k.to_lowercase() == *c,
            _ => false,
        }
    }
}

type TitreSelon<D> = Box<dyn Fn(&D) -> String>;
type Raccourcis<D> = Vec<(Raccourci, Box<dyn Fn(&mut D)>)>;

/// La fenetre : ses ecrans, ses raccourcis, son titre.
pub class Window<D> {
    pub(crate) titre: String,
    pub(crate) titre_selon: Option<TitreSelon<D>>,
    pub(crate) largeur: f32,
    pub(crate) hauteur: f32,
    /// Les ecrans, par nom.
    pub(crate) ecrans: Vec<(&'static str, Rc<RefCell<ScreenDef<D>>>)>,
    pub(crate) affiche: usize,
    pub(crate) raccourcis: Raccourcis<D>,

    pub fn new(title: impl Into<String>, width: f32, height: f32) -> Self {
        Self { titre: title.into(), titre_selon: None, largeur: width, hauteur: height, ecrans: vec![], affiche: 0, raccourcis: vec![], }
    }

    /// L'indice de l'ecran `nom` ; un nom inconnu est une erreur de programmation.
    fn indice(&self, nom: &str) -> usize {
        self.ecrans.iter().position(|(n, _)| *n == nom).unwrap_or_else(|| {
            let connus: Vec<_> = self.ecrans.iter().map(|(n, _)| *n).collect();
            panic!("ecran inconnu : « {nom} » (ecrans declares : {connus:?})")
        })
    }

    /// Titre calcule depuis les donnees (par exemple le nom du fichier ouvert).
    pub fn title_from(&mut self, f: impl Fn(&D) -> String + 'static) {
        self.titre_selon = Some(Box::new(f));
    }

    /// Un nouvel ecran, a remplir.
    /// Son nom le designe partout (`show`, `screen_item`, `add_screen_button`)
    /// et arrive aux fonctions de remplissage.
    pub fn add_screen(&mut self, name: &'static str) -> Screen<D> {
        assert!(self.ecrans.iter().all(|(n, _)| *n != name), "ecran declare deux fois : « {name} »");
        let def = Rc::new(RefCell::new(ScreenDef { menu: None, toolbar: None, content: vec![] }));
        self.ecrans.push((name, def.clone()));
        Screen { name, def }
    }

    /// L'ecran affiche au demarrage.
    pub fn show(&mut self, name: &str) {
        self.affiche = self.indice(name);
    }

    /// Un raccourci clavier : « Ctrl+S », « F5 », « Delete »...
    pub fn add_shortcut(&mut self, keys: &str, action: impl Fn(&mut D) + 'static) {
        let r = Raccourci::lire(keys).unwrap_or_else(|| panic!("raccourci illisible : {keys}"));
        self.raccourcis.push((r, Box::new(action)));
    }

    /// Ouvre la fenetre avec ces donnees, et la fait vivre jusqu'a sa fermeture.
    pub fn run(self, data: D) -> crate::AppResult
    where
        D: 'static,
    {
        let (largeur, hauteur) = (self.largeur, self.hauteur);
        let moteur = Moteur { fenetre: self, doc: data, menu_ouvert: None, actions: RefCell::new(vec![]) };
        iced::application(Moteur::<D>::titre, Moteur::<D>::mise_a_jour, Moteur::<D>::vue)
            .subscription(Moteur::<D>::abonnements)
            .theme(|_| Theme::Dark)
            .antialiasing(true)
            .window_size((largeur, hauteur))
            .run_with(move || (moteur, Task::none()))
    }
}

/// Ce qui tourne : la description de la fenetre, les donnees, l'etat de l'interface.
pub(crate) struct Moteur<D> {
    fenetre: Window<D>,
    doc: D,
    menu_ouvert: Option<usize>,
    actions: Actions<D>,
}

impl<D: 'static> Moteur<D> {
    fn titre(&self) -> String {
        match &self.fenetre.titre_selon {
            Some(f) => f(&self.doc),
            None => self.fenetre.titre.clone(),
        }
    }

    fn mise_a_jour(&mut self, m: Msg) -> Task<Msg> {
        match m {
            Msg::Action(i) => {
                if let Some(Action::Simple(f)) = self.actions.borrow().get(i) {
                    f(&mut self.doc);
                }
                self.menu_ouvert = None;
            }
            Msg::Text(i, t) => {
                if let Some(Action::Text(f)) = self.actions.borrow().get(i) {
                    f(&mut self.doc, t);
                }
            }
            Msg::Toggle(i, v) => {
                if let Some(Action::Toggle(f)) = self.actions.borrow().get(i) {
                    f(&mut self.doc, v);
                }
            }
            Msg::Show(nom) => {
                self.fenetre.affiche = self.fenetre.indice(nom);
                self.menu_ouvert = None;
            }
            Msg::OpenMenu(i) => self.menu_ouvert = if self.menu_ouvert == Some(i) { None } else { Some(i) },
            Msg::CloseMenus => self.menu_ouvert = None,
            Msg::Key(touche, mods) => {
                if touche == Key::Named(Named::Escape) && self.menu_ouvert.is_some() {
                    self.menu_ouvert = None;
                } else if let Some((_, f)) = self.fenetre.raccourcis.iter().find(|(r, _)| r.correspond(&touche, mods)) {
                    f(&mut self.doc);
                }
            }
            Msg::Quit => return iced::exit(),
        }
        Task::none()
    }

    fn vue(&self) -> Element<'_, Msg> {
        // Les actions de l'affichage precedent ne servent plus.
        self.actions.borrow_mut().clear();
        let (id, ecran) = &self.fenetre.ecrans[self.fenetre.affiche];
        let (id, ecran): (&str, _) = (id, ecran.borrow());
        let mut menus = vec![];
        if let Some(f) = &ecran.menu {
            let mut barre = MenuBar::new(&self.actions);
            f(id, &mut barre, &self.doc);
            menus = barre.menus;
        }
        let mut page = column![];
        if !menus.is_empty() {
            page = page.push(crate::menu_bar(&menus, self.menu_ouvert, Msg::OpenMenu));
        }
        if let Some(f) = &ecran.toolbar {
            let mut p = Panel::new(&self.actions, true);
            f(id, &mut p, &self.doc);
            page = page.push(p.into_element(PANEL_BG)).push(crate::horizontal_separator());
        }
        let contenu: Vec<Element<'_, Msg>> = ecran.content.iter().map(|n| self.place(n, id)).collect();
        page = page.push(column(contenu).height(Length::Fill));
        let deroulant = crate::menu_dropdown(&menus, self.menu_ouvert, Msg::CloseMenus);
        stack![page.width(Length::Fill).height(Length::Fill), deroulant].into()
    }

    /// Une place de l'ecran : un panneau rempli, ou un decoupage.
    fn place(&self, n: &Node<D>, id: &str) -> Element<'_, Msg> {
        match n {
            Node::Panel(f) => {
                let mut p = Panel::new(&self.actions, false);
                f(id, &mut p, &self.doc);
                p.into_element(PANEL_BG)
            }
            Node::Split(s) => {
                let s = s.borrow();
                let mut parts: Vec<Element<'_, Msg>> = vec![];
                for (k, enfant) in s.children.iter().enumerate() {
                    if k > 0 {
                        parts.push(match s.direction {
                            Direction::Horizontal => crate::vertical_separator(),
                            Direction::Vertical => crate::horizontal_separator(),
                        });
                    }
                    let poids = s.weights.get(k).copied().unwrap_or(1);
                    let e = self.place(enfant, id);
                    parts.push(match s.direction {
                        Direction::Horizontal => iced::widget::container(e).width(Length::FillPortion(poids)).height(Length::Fill).into(),
                        Direction::Vertical => iced::widget::container(e).height(Length::FillPortion(poids)).width(Length::Fill).into(),
                    });
                }
                match s.direction {
                    Direction::Horizontal => iced::widget::row(parts).height(Length::Fill).into(),
                    Direction::Vertical => iced::widget::column(parts).width(Length::Fill).into(),
                }
            }
        }
    }

    fn abonnements(&self) -> Subscription<Msg> {
        keyboard::on_key_press(|touche, mods| Some(Msg::Key(touche, mods)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn les_raccourcis_se_lisent_comme_on_les_ecrit() {
        let r = Raccourci::lire("Ctrl+S").unwrap();
        assert!(r.correspond(&Key::Character("s".into()), Modifiers::CTRL));
        assert!(!r.correspond(&Key::Character("s".into()), Modifiers::empty()));
        let f5 = Raccourci::lire("F5").unwrap();
        assert!(f5.correspond(&Key::Named(Named::F5), Modifiers::empty()));
        assert!(Raccourci::lire("Ctrl+Shift+Z").unwrap().correspond(&Key::Character("Z".into()), Modifiers::CTRL | Modifiers::SHIFT));
        assert!(Raccourci::lire("Truc").is_none());
    }

    #[derive(Default)]
    struct Doc {
        compteur: i32,
        titre: String,
    }

    /// Le moteur sans fenetre : on affiche, puis on envoie ce qu'un clic enverrait.
    fn moteur() -> Moteur<Doc> {
        let mut w = Window::new("Essai", 800.0, 600.0);
        let accueil = w.add_screen("accueil");
        let reglages = w.add_screen("reglages");
        accueil.add_menu(|_, m: &mut MenuBar<Doc>, _| {
            m.menu("Ecran").screen_item("Reglages", "reglages");
        });
        let s = accueil.add_splitter(Direction::Horizontal, [1, 2]);
        s.add_panel(|ecran, p: &mut Panel<Doc>, d| {
            assert_eq!(ecran, "accueil");
            p.add_text(format!("{}", d.compteur));
            p.add_button("+", |d: &mut Doc| d.compteur += 1);
        });
        s.add_panel(|_, p: &mut Panel<Doc>, _| p.add_screen_button("Reglages", "reglages"));
        reglages.add_panel(|_, p: &mut Panel<Doc>, d| p.add_input("Titre", &d.titre, |d: &mut Doc, t| d.titre = t));
        w.add_shortcut("Ctrl+R", |d: &mut Doc| d.compteur = 0);
        w.show("accueil");
        Moteur { fenetre: w, doc: Doc::default(), menu_ouvert: None, actions: RefCell::new(vec![]) }
    }

    #[test]
    fn un_bouton_modifie_les_donnees_et_un_nom_change_d_ecran() {
        let mut m = moteur();
        let _ = m.vue();
        // Le bouton « + » est la seule action enregistree par l'accueil.
        let _ = m.mise_a_jour(Msg::Action(0));
        let _ = m.mise_a_jour(Msg::Action(0));
        assert_eq!(m.doc.compteur, 2);
        let _ = m.mise_a_jour(Msg::Key(Key::Character("r".into()), Modifiers::CTRL));
        assert_eq!(m.doc.compteur, 0);
        let _ = m.mise_a_jour(Msg::Show("reglages"));
        let _ = m.vue();
        let _ = m.mise_a_jour(Msg::Text(0, "Bonjour".into()));
        assert_eq!(m.doc.titre, "Bonjour");
    }

    /// RUSTUI_CAPTURE=dossier : enregistre l'accueil en PNG pour le regarder.
    #[cfg(feature = "testing")]
    #[test]
    fn capture_de_l_accueil() {
        if let Some(d) = std::env::var_os("RUSTUI_CAPTURE") {
            let m = moteur();
            crate::testing::capture_png(&m.vue(), 900, 400, &std::path::PathBuf::from(d).join("accueil.png"));
        }
    }

    #[test]
    #[should_panic(expected = "ecran inconnu")]
    fn un_nom_d_ecran_inconnu_est_signale() {
        moteur().fenetre.show("ailleurs");
    }
}
