//! Une fenetre pilotee sans l'ouvrir (option `testing`) : on appuie sur des
//! touches, on fait des actions, on regarde les donnees et la mise en page.
//!
//! ```ignore
//! let (fenetre, document) = application::fenetre(None);
//! let mut ui = rust_ui::testing::Harness::new(fenetre, document);
//! ui.press("Ctrl+Z");
//! assert!(ui.data().historique.is_empty());
//! let racine = ui.layout(1280, 800);
//! ```

#[cfg(feature = "testing")]
use crate::screens::{Moteur, Raccourci, Window};

/// La fenetre et ses donnees, comme quand elle tourne.
#[cfg(feature = "testing")]
pub struct Harness<D> {
    moteur: Moteur<D>,
}

#[cfg(feature = "testing")]
impl<D: 'static> Harness<D> {
    pub fn new(window: Window<D>, data: D) -> Self {
        Harness { moteur: Moteur::new(window, data) }
    }

    pub fn data(&self) -> &D {
        &self.moteur.doc
    }

    pub fn data_mut(&mut self) -> &mut D {
        &mut self.moteur.doc
    }

    /// Rend les donnees (la fenetre s'arrete).
    pub fn into_data(self) -> D {
        self.moteur.doc
    }

    /// Appuie sur une touche : « Ctrl+Z », « F5 », « Escape »... Le raccourci
    /// de l'ecran affiche, sinon de la fenetre, s'execute comme a l'ecran.
    pub fn press(&mut self, keys: &str) {
        let (touche, mods) = Raccourci::lire(keys).unwrap_or_else(|| panic!("touche illisible : {keys}")).touche();
        let _ = self.moteur.mise_a_jour(crate::screens::Msg::Key(touche, mods));
    }

    /// Le nom de l'ecran affiche.
    pub fn screen(&self) -> &'static str {
        self.moteur.fenetre.ecrans[self.moteur.ecran()].0
    }

    /// La mise en page de la fenetre a cette taille.
    pub fn layout(&self, width: u32, height: u32) -> iced::advanced::layout::Node {
        crate::testing::layout_of(&self.moteur.vue(), width, height)
    }

    /// La fenetre dessinee a cette taille, en PNG.
    pub fn capture(&self, width: u32, height: u32, path: &std::path::Path) {
        crate::testing::capture_png(&self.moteur.vue(), width, height, path);
    }
}
