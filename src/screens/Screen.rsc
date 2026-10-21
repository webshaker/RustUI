//! Un ecran : sa barre de menus, sa barre d'outils, et son contenu, fait de
//! panneaux eventuellement separes par des `Splitter`. On le decrit une fois au
//! demarrage ; RustUI appelle ensuite les fonctions de remplissage a chaque
//! affichage.

use std::cell::RefCell;
use std::rc::Rc;

import { Panel, MenuBar } from "./Panel.rsc";
import { Raccourci, Raccourcis } from "./Window.rsc";

/// Sens de decoupage d'un `Splitter`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Direction {
    /// Cote a cote (de gauche a droite).
    Horizontal,
    /// L'un sous l'autre (de haut en bas).
    Vertical,
}

/// Fonction de remplissage d'un panneau : l'ecran affiche, le panneau, les donnees.
pub(crate) type Fill<D> = Rc<dyn for<'a> Fn(&str, &mut Panel<'a, D>, &'a D)>;
/// Fonction de remplissage d'une barre de menus.
pub(crate) type FillMenu<D> = Rc<dyn Fn(&str, &mut MenuBar<'_, D>, &D)>;

/// Ce qui occupe une place : un panneau, ou un decoupage en plusieurs places.
pub(crate) enum Node<D> {
    Panel(Fill<D>),
    Split(Rc<RefCell<SplitDef<D>>>),
}

pub(crate) struct SplitDef<D> {
    pub(crate) direction: Direction,
    pub(crate) weights: Vec<u16>,
    pub(crate) children: Vec<Node<D>>,
}

pub(crate) struct ScreenDef<D> {
    pub(crate) menu: Option<FillMenu<D>>,
    pub(crate) toolbar: Option<Fill<D>>,
    pub(crate) statusbar: Option<Fill<D>>,
    pub(crate) content: Vec<Node<D>>,
    /// Raccourcis propres a cet ecran (avant ceux de la fenetre).
    pub(crate) raccourcis: Raccourcis<D>,
}

/// Un ecran, a remplir.
pub class Screen<D> {
    pub(crate) name: &'static str,
    pub(crate) def: Rc<RefCell<ScreenDef<D>>>,

    /// Le nom donne a `add_screen`.
    pub fn name(&self) -> &'static str {
        self.name
    }

    /// La barre de menus de cet ecran.
    pub fn add_menu(&self, fill: impl Fn(&str, &mut MenuBar<'_, D>, &D) + 'static) {
        self.def.borrow_mut().menu = Some(Rc::new(fill));
    }

    /// La barre d'outils, sous les menus (les elements y sont alignes).
    pub fn add_toolbar(&self, fill: impl for<'a> Fn(&str, &mut Panel<'a, D>, &'a D) + 'static) {
        self.def.borrow_mut().toolbar = Some(Rc::new(fill));
    }

    /// La barre d'etat, en bas de l'ecran (une ligne, les elements alignes).
    pub fn add_statusbar(&self, fill: impl for<'a> Fn(&str, &mut Panel<'a, D>, &'a D) + 'static) {
        self.def.borrow_mut().statusbar = Some(Rc::new(fill));
    }

    /// Un raccourci clavier valable sur cet ecran seulement (« Delete », « F9 »...) ;
    /// il passe avant un raccourci de la fenetre sur les memes touches.
    pub fn add_shortcut(&self, keys: &str, action: impl Fn(&mut D) + 'static) {
        let r = Raccourci::lire(keys).unwrap_or_else(|| panic!("raccourci illisible : {keys}"));
        self.def.borrow_mut().raccourcis.push((r, Box::new(action)));
    }

    /// Un panneau qui occupe le contenu de l'ecran.
    pub fn add_panel(&self, fill: impl for<'a> Fn(&str, &mut Panel<'a, D>, &'a D) + 'static) {
        self.def.borrow_mut().content.push(Node::Panel(Rc::new(fill)));
    }

    /// Un decoupage du contenu ; `weights` : part de chaque place (ex. `[1, 2, 1]`).
    pub fn add_splitter(&self, direction: Direction, weights: impl Into<Vec<u16>>) -> Splitter<D> {
        let split = Rc::new(RefCell::new(SplitDef { direction, weights: weights.into(), children: vec![] }));
        self.def.borrow_mut().content.push(Node::Split(split.clone()));
        Splitter { def: split }
    }
}

/// Un decoupage : ses places se remplissent dans l'ordre.
pub class Splitter<D> {
    pub(crate) def: Rc<RefCell<SplitDef<D>>>,

    /// La place suivante est un panneau.
    pub fn add_panel(&self, fill: impl for<'a> Fn(&str, &mut Panel<'a, D>, &'a D) + 'static) {
        self.def.borrow_mut().children.push(Node::Panel(Rc::new(fill)));
    }

    /// La place suivante est elle-meme decoupee.
    pub fn add_splitter(&self, direction: Direction, weights: impl Into<Vec<u16>>) -> Splitter<D> {
        let split = Rc::new(RefCell::new(SplitDef { direction, weights: weights.into(), children: vec![] }));
        self.def.borrow_mut().children.push(Node::Split(split.clone()));
        Splitter { def: split }
    }
}
