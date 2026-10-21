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
import { Action, Actions, Ancien, MenuBar, Msg, Panel } from "./Panel.rsc";
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
type Condition<D> = Box<dyn Fn(&D) -> bool>;
type Rappel<D> = Box<dyn Fn(&mut D)>;
type Modales<D> = Vec<(Condition<D>, Fill<D>, f32)>;
type Minuteries<D> = Vec<(u64, Condition<D>, Box<dyn Fn(&mut D)>)>;
/// Passerelle vers une interface a `Message` (le temps d'une migration).
type Passerelle<D> = Box<dyn Fn(&mut D, Ancien) -> Task<Msg>>;
type AbonnementsAnciens<D> = Box<dyn Fn(&D) -> Subscription<Msg>>;

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
    pub(crate) modales: Modales<D>,
    pub(crate) minuteries: Minuteries<D>,
    pub(crate) sur_fermeture: Option<Rappel<D>>,
    pub(crate) passerelle: Option<Passerelle<D>>,
    pub(crate) abonnements_anciens: Option<AbonnementsAnciens<D>>,
    pub(crate) premiere_tache: Option<Task<Msg>>,

    pub fn new(title: impl Into<String>, width: f32, height: f32) -> Self {
        Self {
            titre: title.into(), titre_selon: None, largeur: width, hauteur: height, ecrans: vec![], affiche: 0, raccourcis: vec![],
            modales: vec![], minuteries: vec![], sur_fermeture: None, passerelle: None, abonnements_anciens: None, premiere_tache: None,
        }
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
            Some(m) => handler(d, m.clone()).map(|m| Msg::Ancien(Ancien(std::sync::Arc::new(m)))),
            None => Task::none(),
        }));
    }

    /// Tache de l'interface a `Message` a lancer au demarrage (par exemple
    /// ouvrir le fichier passe en argument).
    pub fn legacy_first<M: Send + Sync + 'static>(&mut self, task: Task<M>) {
        self.premiere_tache = Some(task.map(|m| Msg::Ancien(Ancien(std::sync::Arc::new(m)))));
    }

    /// Abonnements de l'interface a `Message` (clavier, minuterie...).
    pub fn legacy_subscription<M: Send + Sync + 'static>(&mut self, f: impl Fn(&D) -> Subscription<M> + 'static) {
        self.abonnements_anciens = Some(Box::new(move |d| f(d).map(|m| Msg::Ancien(Ancien(std::sync::Arc::new(m))))));
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

/// Ce qui tourne : la description de la fenetre, les donnees, l'etat de l'interface.
pub(crate) struct Moteur<D> {
    fenetre: Window<D>,
    doc: D,
    menu_ouvert: Option<usize>,
    actions: Actions<D>,
    /// Suites des dialogues de fichier en cours (`Box<dyn Fn(&mut D, PathBuf)>`).
    suites: std::collections::HashMap<u64, Box<dyn std::any::Any>>,
    prochaine_suite: u64,
}

impl<D: 'static> Moteur<D> {
    pub(crate) fn new(fenetre: Window<D>, doc: D) -> Self {
        Moteur { fenetre, doc, menu_ouvert: None, actions: RefCell::new(vec![]), suites: Default::default(), prochaine_suite: 0 }
    }

    fn titre(&self) -> String {
        match &self.fenetre.titre_selon {
            Some(f) => f(&self.doc),
            None => self.fenetre.titre.clone(),
        }
    }

    fn mise_a_jour(&mut self, m: Msg) -> Task<Msg> {
        let tache = self.traiter(m);
        // Ce que les actions ont demande en plus (fichier, ecran, quitter...).
        Task::batch([tache, self.effets()])
    }

    fn traiter(&mut self, m: Msg) -> Task<Msg> {
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
            Msg::Fichier(id, chemin) => {
                if let (Some(suite), Some(chemin)) = (self.suites.remove(&id), chemin)
                    && let Some(f) = suite.downcast_ref::<Box<dyn Fn(&mut D, std::path::PathBuf)>>()
                {
                    f(&mut self.doc, chemin);
                }
            }
            Msg::Timer(k) => {
                if let Some((_, _, f)) = self.fenetre.minuteries.get(k) {
                    f(&mut self.doc);
                }
            }
            Msg::Fermeture => {
                if let Some(f) = &self.fenetre.sur_fermeture {
                    f(&mut self.doc);
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
        s.add_panel(|_, p: &mut Panel<Doc>, _| p.add_screen_button("Reglages", "reglages"));
        reglages.add_panel(|_, p: &mut Panel<Doc>, d| p.add_input("Titre", &d.titre, |d: &mut Doc, t| d.titre = t));
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
            })
        });
        // Modale visible quand le compteur vaut 7 ; son bouton la referme.
        w.add_modal(|d: &Doc| d.compteur == 7, 300.0, |_, p: &mut Panel<Doc>, _| p.add_button("ok", |d: &mut Doc| d.compteur = 0));
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
        let _ = m.mise_a_jour(Msg::Ancien(Ancien(std::sync::Arc::new(Ancien_::Plus(2)))));
        assert_eq!(m.doc.compteur, 2);
    }
}
