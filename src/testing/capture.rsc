//! Outils de test d'interface, sans ouvrir de fenetre (option `testing`) :
//! mise en page d'une vue a une taille donnee, et capture PNG par le moteur
//! logiciel. Pour verifier qu'une vue tient dans la fenetre, ou la regarder.
//!
//! ```ignore
//! let vue = app.view();
//! let racine = rust_ui::testing::layout_of(&vue, 1280, 800);
//! assert_eq!(racine.size(), rust_ui::Size::new(1280.0, 800.0));
//! rust_ui::testing::capture_png(&vue, 1280, 800, "capture.png".as_ref());
//! ```

#[cfg(feature = "testing")]
use iced::advanced::layout::{self, Layout};
#[cfg(feature = "testing")]
use iced::advanced::renderer::Style;
#[cfg(feature = "testing")]
use iced::advanced::widget::Tree;
#[cfg(feature = "testing")]
use iced::{Color, Element, Font, Pixels, Rectangle, Renderer, Size, Theme, mouse};

#[cfg(feature = "testing")]
fn moteur() -> Renderer {
    Renderer::Secondary(iced_tiny_skia::Renderer::new(Font::DEFAULT, Pixels(16.0)))
}

#[cfg(feature = "testing")]
fn disposer<M>(vue: &Element<'_, M>, renderer: &Renderer, largeur: u32, hauteur: u32) -> (Tree, layout::Node) {
    let mut arbre = Tree::new(vue);
    let taille = Size::new(largeur as f32, hauteur as f32);
    let racine = vue.as_widget().layout(&mut arbre, renderer, &layout::Limits::new(Size::ZERO, taille));
    (arbre, racine)
}

/// La mise en page de `vue` dans une fenetre de `largeur` x `hauteur` pixels.
#[cfg(feature = "testing")]
pub fn layout_of<M>(vue: &Element<'_, M>, largeur: u32, hauteur: u32) -> layout::Node {
    disposer(vue, &moteur(), largeur, hauteur).1
}

/// Dessine `vue` (theme sombre, fond `VIEW_BG`) et l'enregistre en PNG.
#[cfg(feature = "testing")]
pub fn capture_png<M>(vue: &Element<'_, M>, largeur: u32, hauteur: u32, chemin: &std::path::Path) {
    let mut renderer = moteur();
    let (arbre, racine) = disposer(vue, &renderer, largeur, hauteur);
    let zone = Rectangle::with_size(Size::new(largeur as f32, hauteur as f32));
    vue.as_widget().draw(&arbre, &mut renderer, &Theme::Dark, &Style { text_color: Color::WHITE }, Layout::new(&racine), mouse::Cursor::Unavailable, &zone);
    let mut pixels = tiny_skia::Pixmap::new(largeur, hauteur).expect("taille de capture non nulle");
    let mut masque = tiny_skia::Mask::new(largeur, hauteur).expect("taille de capture non nulle");
    if let Renderer::Secondary(r) = &mut renderer {
        r.draw::<&str>(
            &mut pixels.as_mut(),
            &mut masque,
            &iced_graphics::Viewport::with_physical_size(Size::new(largeur, hauteur), 1.0),
            &[zone],
            crate::VIEW_BG,
            &[],
        );
    }
    // Le moteur logiciel produit du BGRA (pour softbuffer) ; le PNG attend du RGBA.
    for pixel in pixels.data_mut().chunks_exact_mut(4) {
        pixel.swap(0, 2);
    }
    if let Some(dossier) = chemin.parent() {
        std::fs::create_dir_all(dossier).ok();
    }
    pixels.save_png(chemin).expect("ecriture de la capture PNG");
}
