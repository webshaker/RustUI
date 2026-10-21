//! Les elements d'un panneau, reglables en chaine juste apres leur ajout :
//!
//! ```ignore
//! p.add_text("GRILLÉ").color(rust_ui::RED).size(12);
//! p.add_button("Pause   (F8)", Document::pause).small();
//! p.add_input("100", &tick, Document::changer_tick).width(60.0);
//! ```
//!
//! Ils ne deviennent des widgets iced qu'a la fin du remplissage : c'est ce
//! qui permet de les regler apres coup.

use iced::widget::{Space, button, checkbox, column, container, text, text_input, tooltip};
use iced::{Border, Color, Element, Font, Length};

use crate::colors::*;
import { Msg } from "./Panel.rsc";

/// Un texte.
pub struct Text {
    pub(crate) content: String,
    pub(crate) size: u16,
    pub(crate) color: Color,
    pub(crate) mono: bool,
    pub(crate) single_line: bool,
    pub(crate) width: Option<f32>,
    pub(crate) tooltip: Option<String>,
}

impl Text {
    pub(crate) fn new(content: String, size: u16, color: Color) -> Self {
        Text { content, size, color, mono: false, single_line: false, width: None, tooltip: None }
    }

    /// Taille des caracteres, en pixels.
    pub fn size(&mut self, size: u16) -> &mut Self {
        self.size = size;
        self
    }

    pub fn color(&mut self, color: Color) -> &mut Self {
        self.color = color;
        self
    }

    /// Police a chasse fixe (code, colonnes alignees).
    pub fn mono(&mut self) -> &mut Self {
        self.mono = true;
        self
    }

    /// Une seule ligne, coupee a la largeur disponible : un long texte ne
    /// deforme pas ce qui l'entoure (barre d'etat).
    pub fn single_line(&mut self) -> &mut Self {
        self.single_line = true;
        self
    }

    /// Largeur fixe, en pixels (une colonne de libelles).
    pub fn width(&mut self, pixels: f32) -> &mut Self {
        self.width = Some(pixels);
        self
    }

    /// Une bulle au survol.
    pub fn tooltip(&mut self, t: impl Into<String>) -> &mut Self {
        self.tooltip = Some(t.into());
        self
    }

    pub(crate) fn view<'a>(self) -> Element<'a, Msg> {
        let mut t = text(self.content).size(self.size).color(self.color);
        if self.mono {
            t = t.font(Font::MONOSPACE);
        }
        if let Some(w) = self.width {
            t = t.width(w);
        }
        let mut e: Element<'a, Msg> = if self.single_line {
            let t = t.wrapping(iced::advanced::text::Wrapping::None).width(Length::Fill);
            crate::layer(container(t).width(Length::Fill).height(20))
        } else {
            t.into()
        };
        if let Some(bulle) = self.tooltip {
            let bulle = container(text(bulle).size(12).width(500).wrapping(iced::advanced::text::Wrapping::WordOrGlyph))
                .padding(8)
                .style(|_| container::Style { background: Some(POPUP_BG.into()), border: Border { color: BORDER, width: 1.0, radius: 4.0.into() }, ..Default::default() });
            e = tooltip(e, bulle, tooltip::Position::Top).into();
        }
        e
    }
}

/// L'allure d'un bouton.
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum Kind {
    Normal,
    Primary,
    Secondary,
    Small,
    Accent(Color),
    Tab,
    Flat,
    Link,
    Swatch(Color),
}

/// Un bouton.
pub struct Button {
    pub(crate) label: String,
    pub(crate) detail: Option<(String, Color)>,
    pub(crate) msg: Option<Msg>,
    pub(crate) kind: Kind,
    pub(crate) selected: bool,
    pub(crate) text_color: Option<Color>,
    pub(crate) mono: bool,
    pub(crate) fill: bool,
    pub(crate) size: Option<u16>,
    pub(crate) padding: Option<[u16; 2]>,
}

impl Button {
    pub(crate) fn new(label: String, msg: Option<Msg>) -> Self {
        Button { label, detail: None, msg, kind: Kind::Normal, selected: false, text_color: None, mono: false, fill: false, size: None, padding: None }
    }

    /// Grise et inerte quand `enabled` est faux.
    pub fn enabled(&mut self, enabled: bool) -> &mut Self {
        if !enabled {
            self.msg = None;
        }
        self
    }

    /// Marque le bouton choisi (onglet actif, ligne selectionnee).
    pub fn selected(&mut self, selected: bool) -> &mut Self {
        self.selected = selected;
        self
    }

    /// L'action principale (bleue), dans une modale par exemple.
    pub fn primary(&mut self) -> &mut Self {
        self.kind = Kind::Primary;
        self
    }

    /// Une action secondaire (grise).
    pub fn secondary(&mut self) -> &mut Self {
        self.kind = Kind::Secondary;
        self
    }

    /// Un petit bouton gris.
    pub fn small(&mut self) -> &mut Self {
        self.kind = Kind::Small;
        self
    }

    /// Un bouton de cette couleur (texte blanc).
    pub fn accent(&mut self, color: Color) -> &mut Self {
        self.kind = Kind::Accent(color);
        self
    }

    /// Un onglet : en couleur quand il est `selected`.
    pub fn tab(&mut self) -> &mut Self {
        self.kind = Kind::Tab;
        self
    }

    /// Sans fond : une ligne cliquable, surlignee au survol ou quand elle est `selected`.
    pub fn flat(&mut self) -> &mut Self {
        self.kind = Kind::Flat;
        self
    }

    /// Un lien : texte bleu, blanc au survol.
    pub fn link(&mut self) -> &mut Self {
        self.kind = Kind::Link;
        self
    }

    /// Un carre de couleur (nuancier), entoure quand il est `selected`.
    pub fn swatch(&mut self, color: Color) -> &mut Self {
        self.kind = Kind::Swatch(color);
        self
    }

    /// Couleur du texte.
    pub fn color(&mut self, color: Color) -> &mut Self {
        self.text_color = Some(color);
        self
    }

    /// Police a chasse fixe.
    pub fn mono(&mut self) -> &mut Self {
        self.mono = true;
        self
    }

    /// Toute la largeur disponible.
    pub fn fill(&mut self) -> &mut Self {
        self.fill = true;
        self
    }

    /// Une seconde ligne, plus petite, sous le libelle.
    pub fn detail(&mut self, t: impl Into<String>, color: Color) -> &mut Self {
        self.detail = Some((t.into(), color));
        self
    }

    /// Taille du texte, en pixels.
    pub fn size(&mut self, size: u16) -> &mut Self {
        self.size = Some(size);
        self
    }

    /// Marges interieures (verticale, horizontale), en pixels.
    pub fn padding(&mut self, vertical: u16, horizontal: u16) -> &mut Self {
        self.padding = Some([vertical, horizontal]);
        self
    }

    pub(crate) fn view<'a>(self) -> Element<'a, Msg> {
        let kind = self.kind;
        let taille = self.size.unwrap_or(match kind {
            Kind::Small | Kind::Flat | Kind::Link => 12,
            _ => 13,
        });
        let marge = self.padding.unwrap_or(match kind {
            Kind::Normal => [5, 10],
            Kind::Primary | Kind::Secondary => [6, 16],
            Kind::Small => [3, 8],
            Kind::Accent(_) | Kind::Tab => [5, 14],
            Kind::Flat => [1, 4],
            Kind::Link | Kind::Swatch(_) => [0, 0],
        });
        let mut libelle = text(self.label).size(taille);
        if self.mono {
            libelle = libelle.font(Font::MONOSPACE);
        }
        if let Some(c) = self.text_color {
            libelle = libelle.color(c);
        }
        let contenu: Element<'a, Msg> = match (kind, self.detail) {
            (Kind::Swatch(_), _) => Space::new(18, 18).into(),
            (_, Some((d, c))) => column![libelle, text(d).size(taille.saturating_sub(2)).color(c)].spacing(1).into(),
            (_, None) => libelle.into(),
        };
        let choisi = self.selected;
        let actif = self.msg.is_some();
        let mut b = button(contenu).padding(marge).style(move |theme, statut| style(kind, choisi, actif, theme, statut));
        if self.fill {
            b = b.width(Length::Fill);
        }
        if let Some(m) = self.msg {
            b = b.on_press(m);
        }
        b.into()
    }
}

fn eclairci(c: Color) -> Color {
    Color { r: (c.r * 1.25).min(1.0), g: (c.g * 1.25).min(1.0), b: (c.b * 1.25).min(1.0), a: c.a }
}

fn style(kind: Kind, choisi: bool, actif: bool, theme: &iced::Theme, statut: button::Status) -> button::Style {
    let survol = statut == button::Status::Hovered;
    let arrondi = |r: f32| Border { radius: r.into(), ..Default::default() };
    let gris = |normal: f32, dessus: f32| Color::from_rgb(if survol { dessus } else { normal }, if survol { dessus } else { normal }, if survol { dessus } else { normal });
    match kind {
        Kind::Normal => button::primary(theme, statut),
        Kind::Primary | Kind::Secondary => {
            let fond = match (kind == Kind::Primary, survol) {
                (true, true) => Color::from_rgb(0.3, 0.55, 0.85),
                (true, false) => SELECTION,
                (false, _) => gris(0.25, 0.32),
            };
            button::Style {
                background: Some(if actif { fond } else { Color::from_rgb(0.2, 0.2, 0.2) }.into()),
                text_color: if actif { Color::WHITE } else { TEXT_MUTED },
                border: arrondi(4.0),
                ..Default::default()
            }
        }
        Kind::Small => button::Style {
            background: Some(if survol { Color::from_rgb(0.28, 0.28, 0.31) } else { Color::from_rgb(0.2, 0.2, 0.22) }.into()),
            text_color: if actif { TEXT } else { TEXT_MUTED },
            border: arrondi(3.0),
            ..Default::default()
        },
        Kind::Accent(c) => button::Style {
            background: Some(if !actif { Color::from_rgb(0.2, 0.2, 0.2) } else if survol { eclairci(c) } else { c }.into()),
            text_color: if actif { Color::WHITE } else { TEXT_MUTED },
            border: arrondi(4.0),
            ..Default::default()
        },
        Kind::Tab => button::Style {
            background: Some(if choisi { SELECTION } else if survol { Color::from_rgb(0.25, 0.25, 0.28) } else { Color::from_rgb(0.18, 0.18, 0.2) }.into()),
            text_color: Color::WHITE,
            border: arrondi(4.0),
            ..Default::default()
        },
        Kind::Flat => button::Style {
            background: Some(if choisi { SELECTION } else if survol { Color::from_rgb(0.22, 0.22, 0.24) } else { Color::TRANSPARENT }.into()),
            text_color: TEXT,
            border: arrondi(3.0),
            ..Default::default()
        },
        Kind::Link => button::Style { text_color: if survol { Color::WHITE } else { LINK }, ..Default::default() },
        Kind::Swatch(c) => button::Style {
            background: Some(c.into()),
            border: Border { color: if choisi { Color::WHITE } else { Color::TRANSPARENT }, width: 2.0, radius: 3.0.into() },
            ..Default::default()
        },
    }
}

/// Un champ de saisie.
pub struct Input {
    pub(crate) placeholder: String,
    pub(crate) value: String,
    pub(crate) action: usize,
    pub(crate) width: Option<f32>,
    pub(crate) size: u16,
}

impl Input {
    /// Largeur fixe, en pixels.
    pub fn width(&mut self, pixels: f32) -> &mut Self {
        self.width = Some(pixels);
        self
    }

    /// Taille du texte, en pixels.
    pub fn size(&mut self, size: u16) -> &mut Self {
        self.size = size;
        self
    }

    pub(crate) fn view<'a>(self) -> Element<'a, Msg> {
        let i = self.action;
        let mut t = text_input(&self.placeholder, &self.value).size(self.size).padding(4).on_input(move |t| Msg::Text(i, t));
        if let Some(w) = self.width {
            t = t.width(w);
        }
        t.into()
    }
}

/// Une case a cocher.
pub struct CheckBox {
    pub(crate) label: String,
    pub(crate) checked: bool,
    pub(crate) action: usize,
    pub(crate) text_size: u16,
}

impl CheckBox {
    /// Taille du libelle, en pixels.
    pub fn text_size(&mut self, size: u16) -> &mut Self {
        self.text_size = size;
        self
    }

    pub(crate) fn view<'a>(self) -> Element<'a, Msg> {
        let i = self.action;
        checkbox(self.label, self.checked).size(14).text_size(self.text_size).on_toggle(move |v| Msg::Toggle(i, v)).into()
    }
}
