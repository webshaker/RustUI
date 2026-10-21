//! Une application decrite par ecrans : `cargo run --example compteur`.
//!
//! Les donnees sont dans `Document`. La structure (ecrans, menus, decoupage)
//! est decrite une fois dans `main`. Chaque panneau est rempli par une
//! fonction qui recoit l'ecran affiche, le panneau et les donnees ; chaque
//! bouton est relie directement a l'action qui modifie les donnees.
use rust_ui::{Direction, MenuBar, Panel, Window};

/// Toutes les donnees de l'application.
struct Document {
    counter: i32,
    title: String,
    step: i32,
    negative_allowed: bool,
}

impl Document {
    fn increment(&mut self) {
        self.counter += self.step;
    }

    fn decrement(&mut self) {
        if self.negative_allowed || self.counter - self.step >= 0 {
            self.counter -= self.step;
        }
    }
}

fn main() -> rust_ui::AppResult {
    let mut window = Window::new("Mon application", 1200.0, 700.0);

    let home = window.add_screen("home");
    let settings = window.add_screen("settings");

    home.add_menu(draw_menu);
    home.add_toolbar(draw_toolbar);
    let split = home.add_splitter(Direction::Horizontal, [1, 2, 1]);
    split.add_panel(draw_left);
    split.add_panel(draw_center);
    split.add_panel(draw_right);

    settings.add_menu(draw_menu);
    settings.add_panel(draw_settings);

    window.add_shortcut("Ctrl+R", |doc: &mut Document| doc.counter = 0);
    window.add_shortcut("Up", Document::increment);
    window.add_shortcut("Down", Document::decrement);
    window.title_from(|doc: &Document| format!("{} — {}", doc.title, doc.counter));

    window.show("home");
    window.run(Document { counter: 0, title: "Mon application".into(), step: 1, negative_allowed: false })
}

/// Le meme menu sur les deux ecrans ; « Ecran » mene de l'un a l'autre.
fn draw_menu(_screen: &str, menu: &mut MenuBar<Document>, doc: &Document) {
    menu.menu("Fichier")
        .item_if("Remettre a zero   Ctrl+R", doc.counter != 0, |doc| doc.counter = 0)
        .quit_item("Quitter");
    menu.menu("Ecran").screen_item("Accueil", "home").screen_item("Reglages", "settings");
}

fn draw_toolbar(_screen: &str, bar: &mut Panel<Document>, doc: &Document) {
    bar.add_button("-", Document::decrement);
    bar.add_button("+", Document::increment);
    bar.add_space();
    bar.add_note(format!("pas : {}", doc.step));
}

fn draw_left(_screen: &str, panel: &mut Panel<Document>, doc: &Document) {
    panel.add_title(&doc.title);
    panel.add_button("Incrementer", Document::increment);
    panel.add_button("Decrementer", Document::decrement);
}

fn draw_center(_screen: &str, panel: &mut Panel<Document>, doc: &Document) {
    panel.add_title(format!("Compteur : {}", doc.counter));
    panel.add_note("Fleches haut / bas, ou les boutons.");
}

fn draw_right(_screen: &str, panel: &mut Panel<Document>, _doc: &Document) {
    panel.add_text("Les reglages sont sur l'autre ecran.");
    panel.add_screen_button("Ouvrir les reglages", "settings");
}

fn draw_settings(_screen: &str, panel: &mut Panel<Document>, doc: &Document) {
    panel.add_title("Reglages");
    panel.add_input("Titre", &doc.title, |doc, t| doc.title = t);
    panel.add_input("Pas", &doc.step.to_string(), |doc, t| {
        if let Ok(p) = t.parse() {
            doc.step = p;
        }
    });
    panel.add_checkbox("Autoriser les valeurs negatives", doc.negative_allowed, |doc, v| doc.negative_allowed = v);
    panel.add_screen_button("Retour", "home");
}
