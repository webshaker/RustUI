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
import { Action, Actions, MenuBar, Msg, Panel, Payload } from "./Panel.rsc";
import { Effet } from "./effects.rsc";
import { Direction, Fill, Node, Screen, ScreenDef } from "./Screen.rsc";

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
    pub(crate) fn lire(texte: &str) -> Option<Self> {
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

    /// La touche et les modificateurs que ce raccourci attend (pour simuler un appui).
    #[cfg(feature = "testing")]
    pub(crate) fn touche(&self) -> (Key, Modifiers) {
        let mut m = Modifiers::empty();
        if self.ctrl {
            m |= Modifiers::CTRL;
        }
        if self.shift {
            m |= Modifiers::SHIFT;
        }
        if self.alt {
            m |= Modifiers::ALT;
        }
        let k = match &self.touche {
            Touche::Nommee(n) => Key::Named(*n),
            Touche::Caractere(c) => Key::Character(c.as_str().into()),
        };
        (k, m)
    }

    pub(crate) fn correspond(&self, touche: &Key, m: Modifiers) -> bool {
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
pub(crate) type Raccourcis<D> = Vec<(Raccourci, Box<dyn Fn(&mut D)>)>;
type Condition<D> = Box<dyn Fn(&D) -> bool>;
type Rappel<D> = Box<dyn Fn(&mut D)>;
/// Enveloppe de toutes les actions (historique d'annulation, recalculs...).
type Enveloppe<D> = Box<dyn Fn(&mut D, &mut dyn FnMut(&mut D))>;
type Modales<D> = Vec<(Condition<D>, Fill<D>, f32)>;
type Minuteries<D> = Vec<(u64, Condition<D>, Box<dyn Fn(&mut D)>)>;
/// Passerelle vers une interface a `Message` (le temps d'une migration).
type Passerelle<D> = Box<dyn Fn(&mut D, Payload) -> Task<Msg>>;
type AbonnementsAnciens<D> = Box<dyn Fn(&D) -> Subscription<Msg>>;
type EcranSelon<D> = Box<dyn Fn(&D) -> &'static str>;

/// La fenetre : ses ecrans, ses raccourcis, son titre.
pub class Window<D> {
    pub(crate) titre: String,
    pub(crate) titre_selon: Option<TitreSelon<D>>,
    pub(crate) largeur: f32,
    pub(crate) hauteur: f32,
    /// Les ecrans, par nom.
    pub(crate) ecrans: Vec<(&'static str, Rc<RefCell<ScreenDef<D>>>)>,
    pub(crate) affiche: usize,
    /// L'ecran affiche, choisi par les donnees (`screen_from`).
    pub(crate) ecran_selon: Option<EcranSelon<D>>,
    pub(crate) raccourcis: Raccourcis<D>,
    pub(crate) modales: Modales<D>,
    pub(crate) minuteries: Minuteries<D>,
    pub(crate) sur_fermeture: Option<Rappel<D>>,
    pub(crate) passerelle: Option<Passerelle<D>>,
    pub(crate) abonnements_anciens: Option<AbonnementsAnciens<D>>,
    pub(crate) premiere_tache: Option<Task<Msg>>,
    pub(crate) enveloppe: Option<Enveloppe<D>>,

    pub fn new(title: impl Into<String>, width: f32, height: f32) -> Self {
        Self {
            titre: title.into(), titre_selon: None, largeur: width, hauteur: height, ecrans: vec![], affiche: 0, ecran_selon: None, raccourcis: vec![],
            modales: vec![], minuteries: vec![], sur_fermeture: None, passerelle: None, abonnements_anciens: None, premiere_tache: None, enveloppe: None,
        }
    }

    /// Toute action de l'interface (bouton, menu, raccourci, minuterie, suite
    /// d'un dialogue) passe par `around` : par exemple pour garder l'etat
    /// precedent des donnees (annuler) ou recalculer ce qui en depend.
    pub fn around_actions(&mut self, around: impl Fn(&mut D, &mut dyn FnMut(&mut D)) + 'static) {
        self.enveloppe = Some(Box::new(around));
    }

    /// Une fenetre modale, par-dessus l'ecran tant que `when` est vrai
    /// (par exemple « des modifications seront perdues »). Une action de la
    /// modale remet la condition a faux pour la fermer.
    pub fn add_modal(&mut self, when: impl Fn(&D) -> bool + 'static, width: f32, fill: impl for<'a> Fn(&str, &mut Panel<'a, D>, &'a D) + 'static) {
        self.modales.push((Box::new(when), Rc::new(fill), width));
    }

    /// La croix de la fenetre appelle `action` au lieu de fermer ; elle
    /// ferme avec `rust_ui::quit()` (par exemple apres confirmation).
    pub fn on_close(&mut self, action: impl Fn(&mut D) + 'static) {
        self.sur_fermeture = Some(Box::new(action));
    }

    /// Appelle `action` toutes les `millis` ms tant que `when` est vrai
    /// (option `tokio`).
    #[cfg(feature = "tokio")]
    pub fn add_timer(&mut self, millis: u64, when: impl Fn(&D) -> bool + 'static, action: impl Fn(&mut D) + 'static) {
        self.minuteries.push((millis, Box::new(when), Box::new(action)));
    }

    /// Passerelle de migration : les elements a `Message` places par
    /// `Panel::add_legacy` sont traites par `handler`, comme avant.
    pub fn legacy<M: Clone + Send + Sync + 'static>(&mut self, handler: impl Fn(&mut D, M) -> Task<M> + 'static) {
        self.passerelle = Some(Box::new(move |d, ancien| match ancien.0.downcast_ref::<M>() {
            Some(m) => handler(d, m.clone()).map(|m| Msg::Ancien(Payload(std::sync::Arc::new(m)))),
            None => Task::none(),
        }));
    }

    /// Tache de l'interface a `Message` a lancer au demarrage (par exemple
    /// ouvrir le fichier passe en argument).
    pub fn legacy_first<M: Send + Sync + 'static>(&mut self, task: Task<M>) {
        self.premiere_tache = Some(task.map(|m| Msg::Ancien(Payload(std::sync::Arc::new(m)))));
    }

    /// Abonnements de l'interface a `Message` (clavier, minuterie...).
    pub fn legacy_subscription<M: Send + Sync + 'static>(&mut self, f: impl Fn(&D) -> Subscription<M> + 'static) {
        self.abonnements_anciens = Some(Box::new(move |d| f(d).map(|m| Msg::Ancien(Payload(std::sync::Arc::new(m))))));
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
        let def = Rc::new(RefCell::new(ScreenDef { menu: None, toolbar: None, statusbar: None, content: vec![], raccourcis: vec![] }));
        self.ecrans.push((name, def.clone()));
        Screen { name, def }
    }

    /// L'ecran affiche au demarrage.
    pub fn show(&mut self, name: &str) {
        self.affiche = self.indice(name);
    }

    /// L'ecran affiche est choisi par les donnees : `f` rend son nom. Les
    /// actions changent alors d'ecran en changeant les donnees (un onglet
    /// courant dans le document, par exemple) ; `show_screen` et les boutons
    /// d'ecran sont sans effet.
    pub fn screen_from(&mut self, f: impl Fn(&D) -> &'static str + 'static) {
        self.ecran_selon = Some(Box::new(f));
    }

    /// Un raccourci clavier de toute la fenetre : « Ctrl+S », « F5 », « Delete »...
    /// Tant qu'une modale est ouverte, seul « Escape » est transmis.
    pub fn add_shortcut(&mut self, keys: &str, action: impl Fn(&mut D) + 'static) {
        let r = Raccourci::lire(keys).unwrap_or_else(|| panic!("raccourci illisible : {keys}"));
        self.raccourcis.push((r, Box::new(action)));
    }

    /// Ouvre la fenetre avec ces donnees, et la fait vivre jusqu'a sa fermeture.
    pub fn run(mut self, data: D) -> crate::AppResult
    where
        D: 'static,
    {
        let premiere = self.premiere_tache.take().unwrap_or_else(Task::none);
        let reglages = iced::window::Settings {
            size: iced::Size::new(self.largeur, self.hauteur),
            exit_on_close_request: self.sur_fermeture.is_none(),
            ..Default::default()
        };
        let moteur = Moteur::new(self, data);
        iced::application(Moteur::<D>::titre, Moteur::<D>::mise_a_jour, Moteur::<D>::vue)
            .subscription(Moteur::<D>::abonnements)
            .theme(|_| Theme::Dark)
            .antialiasing(true)
            .window(reglages)
            .run_with(move || (moteur, premiere))
    }
}

/// Une action, passee par l'enveloppe si la fenetre en a une.
fn executer<D>(enveloppe: &Option<Enveloppe<D>>, doc: &mut D, action: impl FnOnce(&mut D)) {
    match enveloppe {
        Some(e) => {
            let mut action = Some(action);
            e(doc, &mut |d| {
                if let Some(a) = action.take() {
                    a(d)
                }
            });
        }
        None => action(doc),
    }
}

/// Ce qui tourne : la description de la fenetre, les donnees, l'etat de l'interface.
pub(crate) struct Moteur<D> {
    pub(crate) fenetre: Window<D>,
    pub(crate) doc: D,
    menu_ouvert: Option<usize>,
    sous_menu: Option<usize>,
    actions: Actions<D>,
    /// Suites des dialogues de fichier en cours (`Box<dyn Fn(&mut D, PathBuf)>`).
    suites: std::collections::HashMap<u64, Box<dyn std::any::Any>>,
    prochaine_suite: u64,
}

impl<D: 'static> Moteur<D> {
    pub(crate) fn new(fenetre: Window<D>, doc: D) -> Self {
        Moteur { fenetre, doc, menu_ouvert: None, sous_menu: None, actions: RefCell::new(vec![]), suites: Default::default(), prochaine_suite: 0 }
    }

    fn titre(&self) -> String {
        match &self.fenetre.titre_selon {
            Some(f) => f(&self.doc),
            None => self.fenetre.titre.clone(),
        }
    }

    /// L'indice de l'ecran affiche (choisi par les donnees, s'il y a lieu).
    pub(crate) fn ecran(&self) -> usize {
        match &self.fenetre.ecran_selon {
            Some(f) => self.fenetre.indice(f(&self.doc)),
            None => self.fenetre.affiche,
        }
    }

    /// Une modale est ouverte.
    fn modale(&self) -> bool {
        self.fenetre.modales.iter().any(|(quand, _, _)| quand(&self.doc))
    }

    pub(crate) fn mise_a_jour(&mut self, m: Msg) -> Task<Msg> {
        let tache = self.traiter(m);
        // Ce que les actions ont demande en plus (fichier, ecran, quitter...).
        Task::batch([tache, self.effets()])
    }

    fn traiter(&mut self, m: Msg) -> Task<Msg> {
        match m {
            Msg::Action(i) => {
                if let Some(Action::Simple(f)) = self.actions.borrow().get(i) {
                    executer(&self.fenetre.enveloppe, &mut self.doc, |d| f(d));
                }
                self.menu_ouvert = None;
                self.sous_menu = None;
            }
            Msg::Text(i, t) => {
                if let Some(Action::Text(f)) = self.actions.borrow().get(i) {
                    executer(&self.fenetre.enveloppe, &mut self.doc, |d| f(d, t));
                }
            }
            Msg::Toggle(i, v) => {
                if let Some(Action::Toggle(f)) = self.actions.borrow().get(i) {
                    executer(&self.fenetre.enveloppe, &mut self.doc, |d| f(d, v));
                }
            }
            Msg::Event(i, p) => {
                if let Some(Action::Event(f)) = self.actions.borrow().get(i) {
                    executer(&self.fenetre.enveloppe, &mut self.doc, |d| f(d, &p));
                }
            }
            Msg::Show(nom) => {
                self.fenetre.affiche = self.fenetre.indice(nom);
                self.menu_ouvert = None;
            }
            Msg::OpenMenu(i) => {
                self.menu_ouvert = if self.menu_ouvert == Some(i) { None } else { Some(i) };
                self.sous_menu = None;
            }
            Msg::OpenSubmenu(k) => self.sous_menu = Some(k),
            Msg::CloseMenus => {
                self.menu_ouvert = None;
                self.sous_menu = None;
            }
            Msg::Key(touche, mods) => {
                let echap = touche == Key::Named(Named::Escape);
                if echap && self.menu_ouvert.is_some() {
                    self.menu_ouvert = None;
                } else if echap || !self.modale() {
                    // Les raccourcis de l'ecran, puis ceux de la fenetre.
                    let ecran = self.fenetre.ecrans[self.ecran()].1.clone();
                    let ecran = ecran.borrow();
                    let trouve = |l: &Raccourcis<D>| l.iter().position(|(r, _)| r.correspond(&touche, mods));
                    if let Some(k) = trouve(&ecran.raccourcis) {
                        executer(&self.fenetre.enveloppe, &mut self.doc, |d| (ecran.raccourcis[k].1)(d));
                    } else if let Some(k) = trouve(&self.fenetre.raccourcis) {
                        executer(&self.fenetre.enveloppe, &mut self.doc, |d| (self.fenetre.raccourcis[k].1)(d));
                    }
                }
            }
            Msg::Fichier(id, chemin) => {
                if let (Some(suite), Some(chemin)) = (self.suites.remove(&id), chemin)
                    && let Some(f) = suite.downcast_ref::<Box<dyn Fn(&mut D, std::path::PathBuf)>>()
                {
                    executer(&self.fenetre.enveloppe, &mut self.doc, |d| f(d, chemin));
                }
            }
            Msg::Timer(k) => {
                if let Some((_, _, f)) = self.fenetre.minuteries.get(k) {
                    executer(&self.fenetre.enveloppe, &mut self.doc, |d| f(d));
                }
            }
            Msg::Fermeture => {
                if let Some(f) = &self.fenetre.sur_fermeture {
                    executer(&self.fenetre.enveloppe, &mut self.doc, |d| f(d));
                }
            }
            Msg::Ancien(a) => {
                if let Some(p) = &self.fenetre.passerelle {
                    return p(&mut self.doc, a);
                }
            }
            Msg::Rien => {}
            Msg::Quit => return iced::exit(),
        }
        Task::none()
    }

    /// Execute les effets demandes par les actions (voir `effects.rsc`).
    fn effets(&mut self) -> Task<Msg> {
        let mut taches = vec![];
        for e in super::effects::prendre() {
            match e {
                Effet::Ecran(nom) => self.fenetre.affiche = self.fenetre.indice(&nom),
                Effet::Copier(t) => taches.push(iced::clipboard::write(t)),
                Effet::Quitter => taches.push(iced::exit()),
                Effet::Fichier { titre, filtres, enregistrer, dossier, suite } => {
                    let id = self.prochaine_suite;
                    self.prochaine_suite += 1;
                    self.suites.insert(id, suite);
                    let mut d = rfd::AsyncFileDialog::new().set_title(&titre);
                    for (nom, ext) in &filtres {
                        d = d.add_filter(nom, ext);
                    }
                    if let Some(dossier) = dossier {
                        d = d.set_directory(dossier);
                    }
                    taches.push(match enregistrer {
                        Some(nom) => Task::perform(d.set_file_name(nom).save_file(), move |h| Msg::Fichier(id, h.map(|h| h.path().to_path_buf()))),
                        None => Task::perform(d.pick_file(), move |h| Msg::Fichier(id, h.map(|h| h.path().to_path_buf()))),
                    });
                }
            }
        }
        Task::batch(taches)
    }

    pub(crate) fn vue(&self) -> Element<'_, Msg> {
        // Les actions de l'affichage precedent ne servent plus.
        self.actions.borrow_mut().clear();
        let (id, ecran) = &self.fenetre.ecrans[self.ecran()];
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
        let contenu: Vec<Element<'_, Msg>> = ecran.content.iter().filter_map(|n| self.place(n, id)).map(|(e, _, _)| e).collect();
        page = page.push(column(contenu).height(Length::Fill));
        if let Some(f) = &ecran.statusbar {
            let mut p = Panel::new(&self.actions, true);
            p.espacement = Some(12);
            f(id, &mut p, &self.doc);
            page = page.push(crate::horizontal_separator()).push(p.into_element(MENU_BG));
        }
        let deroulant = crate::menu_dropdown_sub(&menus, self.menu_ouvert, self.sous_menu, Msg::CloseMenus, Msg::OpenSubmenu);
        let mut couches = stack![page.width(Length::Fill).height(Length::Fill), deroulant];
        for (quand, f, largeur) in &self.fenetre.modales {
            if quand(&self.doc) {
                let mut p = Panel::new(&self.actions, false);
                f(id, &mut p, &self.doc);
                couches = couches.push(crate::modal(p.into_content(), *largeur, Msg::Rien));
            }
        }
        couches.into()
    }

    /// Une place de l'ecran : un panneau rempli, ou un decoupage ; avec la
    /// largeur et la hauteur fixes demandees par le panneau. `None` : cache.
    fn place(&self, n: &Node<D>, id: &str) -> Option<(Element<'_, Msg>, Option<f32>, Option<f32>)> {
        match n {
            Node::Panel(f) => {
                let mut p = Panel::new(&self.actions, false);
                f(id, &mut p, &self.doc);
                if p.cache {
                    return None;
                }
                let (largeur, hauteur) = (p.largeur, p.hauteur);
                Some((p.into_element(PANEL_BG), largeur, hauteur))
            }
            Node::Split(s) => {
                let s = s.borrow();
                let mut parts: Vec<Element<'_, Msg>> = vec![];
                for (k, enfant) in s.children.iter().enumerate() {
                    let Some((e, largeur, hauteur)) = self.place(enfant, id) else { continue };
                    if !parts.is_empty() {
                        parts.push(match s.direction {
                            Direction::Horizontal => crate::vertical_separator(),
                            Direction::Vertical => crate::horizontal_separator(),
                        });
                    }
                    let part = Length::FillPortion(s.weights.get(k).copied().unwrap_or(1));
                    parts.push(match s.direction {
                        Direction::Horizontal => iced::widget::container(e).width(largeur.map(Length::Fixed).unwrap_or(part)).height(Length::Fill).into(),
                        Direction::Vertical => iced::widget::container(e).height(hauteur.map(Length::Fixed).unwrap_or(part)).width(Length::Fill).into(),
                    });
                }
                if parts.is_empty() {
                    return None;
                }
                let e = match s.direction {
                    Direction::Horizontal => iced::widget::row(parts).height(Length::Fill).into(),
                    Direction::Vertical => iced::widget::column(parts).width(Length::Fill).into(),
                };
                Some((e, None, None))
            }
        }
    }

    fn abonnements(&self) -> Subscription<Msg> {
        let mut a = vec![keyboard::on_key_press(|touche, mods| Some(Msg::Key(touche, mods)))];
        if self.fenetre.sur_fermeture.is_some() {
            a.push(iced::window::close_requests().map(|_| Msg::Fermeture));
        }
        #[cfg(feature = "tokio")]
        for (k, (ms, quand, _)) in self.fenetre.minuteries.iter().enumerate() {
            if quand(&self.doc) {
                // `with` : l'indice suit l'abonnement sans capture (exige par iced).
                a.push(iced::time::every(std::time::Duration::from_millis(*ms)).with(k).map(|(k, _)| Msg::Timer(k)));
            }
        }
        if let Some(f) = &self.fenetre.abonnements_anciens {
            a.push(f(&self.doc));
        }
        Subscription::batch(a)
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
        s.add_panel(|_, p: &mut Panel<Doc>, _| { p.add_screen_button("Reglages", "reglages"); });
        reglages.add_panel(|_, p: &mut Panel<Doc>, d| { p.add_input("Titre", &d.titre, |d: &mut Doc, t| d.titre = t); });
        w.add_shortcut("Ctrl+R", |d: &mut Doc| d.compteur = 0);
        w.show("accueil");
        Moteur::new(w, Doc::default())
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

    #[test]
    fn une_action_peut_changer_d_ecran_et_une_modale_s_affiche_selon_les_donnees() {
        let mut w = Window::new("Essai", 800.0, 600.0);
        let a = w.add_screen("a");
        w.add_screen("b");
        a.add_panel(|_, p: &mut Panel<Doc>, _| {
            p.add_button("aller", |d: &mut Doc| {
                d.compteur = 7;
                crate::show_screen("b");
            });
        });
        // Modale visible quand le compteur vaut 7 ; son bouton la referme.
        w.add_modal(|d: &Doc| d.compteur == 7, 300.0, |_, p: &mut Panel<Doc>, _| { p.add_button("ok", |d: &mut Doc| d.compteur = 0); });
        let mut m = Moteur::new(w, Doc::default());
        let _ = m.vue();
        let _ = m.mise_a_jour(Msg::Action(0));
        assert_eq!((m.doc.compteur, m.fenetre.affiche), (7, 1), "action executee, puis ecran « b »");
        let _ = m.vue();
        // L'ecran « b » est vide : la seule action est le bouton de la modale.
        let _ = m.mise_a_jour(Msg::Action(0));
        assert_eq!(m.doc.compteur, 0);
    }

    #[derive(Debug, Clone)]
    enum Ancien_ {
        Plus(i32),
    }

    #[test]
    fn la_passerelle_traite_les_messages_d_avant() {
        let mut w = Window::new("Essai", 800.0, 600.0);
        w.add_screen("a").add_panel(|_, p: &mut Panel<Doc>, _| p.add_legacy(iced::widget::button("+").on_press(Ancien_::Plus(2))));
        w.legacy(|d: &mut Doc, m: Ancien_| {
            let Ancien_::Plus(n) = m;
            d.compteur += n;
            Task::none()
        });
        let mut m = Moteur::new(w, Doc::default());
        let _ = m.vue();
        let _ = m.mise_a_jour(Msg::Ancien(Payload(std::sync::Arc::new(Ancien_::Plus(2)))));
        assert_eq!(m.doc.compteur, 2);
    }

    /// L'ecran suit les donnees ; les raccourcis de l'ecran passent avant ceux
    /// de la fenetre ; une modale ne laisse passer que « Escape ».
    #[test]
    fn ecran_choisi_par_les_donnees_raccourcis_d_ecran_et_modale() {
        let mut w = Window::new("Essai", 800.0, 600.0);
        let a = w.add_screen("a");
        w.add_screen("b");
        w.screen_from(|d: &Doc| if d.compteur >= 10 { "b" } else { "a" });
        a.add_shortcut("R", |d: &mut Doc| d.compteur += 10);
        w.add_shortcut("R", |d: &mut Doc| d.compteur += 1);
        w.add_shortcut("Escape", |d: &mut Doc| d.titre.clear());
        w.add_modal(|d: &Doc| !d.titre.is_empty(), 300.0, |_, _, _| {});
        let mut m = Moteur::new(w, Doc::default());
        let r = || Msg::Key(Key::Character("r".into()), Modifiers::empty());
        let _ = m.mise_a_jour(r());
        assert_eq!((m.doc.compteur, m.ecran()), (10, 1), "raccourci de « a », puis ecran « b »");
        let _ = m.mise_a_jour(r());
        assert_eq!(m.doc.compteur, 11, "sur « b », celui de la fenetre");
        m.doc.titre = "modale".into();
        let _ = m.mise_a_jour(r());
        assert_eq!(m.doc.compteur, 11, "la modale garde le clavier");
        let _ = m.mise_a_jour(Msg::Key(Key::Named(Named::Escape), Modifiers::empty()));
        assert!(m.doc.titre.is_empty(), "sauf Escape");
    }

    /// Un panneau cache laisse sa place ; un widget a evenements les rend a son action.
    #[test]
    fn panneau_cache_et_evenements_d_un_widget() {
        let mut w = Window::new("Essai", 800.0, 600.0);
        let s = w.add_screen("a").add_splitter(Direction::Horizontal, [1, 1]);
        s.add_panel(|_, p: &mut Panel<Doc>, _| {
            p.set_width(200.0);
            p.hide();
        });
        s.add_panel(|_, p: &mut Panel<Doc>, d| {
            p.add_widget(iced::widget::slider(0.0..=10.0, d.compteur as f32, |v| v), |d: &mut Doc, v: f32| d.compteur = v as i32);
        });
        let mut m = Moteur::new(w, Doc::default());
        let _ = m.vue();
        let _ = m.mise_a_jour(Msg::Event(0, Payload(std::sync::Arc::new(4.0_f32))));
        assert_eq!(m.doc.compteur, 4);
        let ecran = m.fenetre.ecrans[0].1.clone();
        let ecran = ecran.borrow();
        let (_, largeur, _) = m.place(&ecran.content[0], "a").unwrap();
        assert_eq!(largeur, None, "seul le second panneau reste : pas de largeur fixe");
    }
}
