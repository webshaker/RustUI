//! Coloration syntaxique du C dans l'editeur, et marques du debogage : la
//! ligne ou l'execution est arretee, les lignes qui portent un point d'arret.

use std::ops::Range;
use iced::Color;
use iced::advanced::text::highlighter::{self, Highlighter};

/// Ce qui change la coloration : lignes (0 = la premiere).
#[derive(Debug, Clone, PartialEq, Default)]
pub class Reglages {
    pub arret: Option<usize>,
    pub points: Vec<usize>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Genre {
    Commentaire,
    Chaine,
    Preprocesseur,
    MotCle,
    Type,
    Nombre,
    Fonction,
    Macro,
    /// La ligne ou l'execution est arretee.
    Arret,
    /// Une ligne qui porte un point d'arret.
    PointArret,
}

impl Genre {
    pub fn format(g: &Genre, _theme: &iced::Theme) -> highlighter::Format<iced::Font> {
        let couleur = match g {
            Genre::Commentaire => Color::from_rgb(0.42, 0.6, 0.33),
            Genre::Chaine => Color::from_rgb(0.81, 0.57, 0.47),
            Genre::Preprocesseur => Color::from_rgb(0.77, 0.53, 0.75),
            Genre::MotCle => Color::from_rgb(0.34, 0.61, 0.84),
            Genre::Type => Color::from_rgb(0.31, 0.79, 0.69),
            Genre::Nombre => Color::from_rgb(0.71, 0.81, 0.66),
            Genre::Fonction => Color::from_rgb(0.86, 0.86, 0.67),
            Genre::Macro => Color::from_rgb(0.31, 0.75, 1.0),
            Genre::Arret => Color::WHITE,
            Genre::PointArret => Color::from_rgb(1.0, 0.45, 0.45),
        };
        let gras = matches!(g, Genre::Arret).then_some(iced::Font { weight: iced::font::Weight::Bold, ..iced::Font::MONOSPACE });
        highlighter::Format { color: Some(couleur), font: gras }
    }
}

const MOTS_CLES: &[&str] = &[
    "if", "else", "for", "while", "do", "return", "switch", "case", "break", "continue", "default", "goto", "sizeof", "typedef", "struct",
    "union", "enum", "static", "const", "volatile", "extern", "inline", "register", "true", "false", "NULL",
];

const TYPES: &[&str] = &[
    "void", "int", "char", "short", "long", "unsigned", "signed", "float", "double", "bool", "size_t", "int8_t", "int16_t", "int32_t",
    "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t",
];

pub class ColorationC {
    reglages: Reglages,
    ligne: usize,
    /// Pour chaque ligne deja vue : commence-t-elle dans un commentaire /* */ ?
    dans_commentaire: Vec<bool>,

    impl Highlighter {
        type Settings = Reglages;
        type Highlight = Genre;
        type Iterator<'a> = std::vec::IntoIter<(Range<usize>, Genre)>;

        fn new(reglages: &Reglages) -> Self {
            ColorationC { reglages: reglages.clone(), ligne: 0, dans_commentaire: vec![false] }
        }

        fn update(&mut self, reglages: &Reglages) {
            self.reglages = reglages.clone();
            self.change_line(0);
        }

        fn change_line(&mut self, ligne: usize) {
            self.ligne = ligne.min(self.dans_commentaire.len() - 1);
            self.dans_commentaire.truncate(self.ligne + 1);
        }

        fn highlight_line(&mut self, texte: &str) -> Self::Iterator<'_> {
            let n = self.ligne;
            let debut_commentaire = self.dans_commentaire.get(n).copied().unwrap_or(false);
            let (spans, fin_commentaire) = colorer(texte, debut_commentaire);
            self.dans_commentaire.truncate(n + 1);
            self.dans_commentaire.push(fin_commentaire);
            self.ligne = n + 1;
            // Les marques du debogage passent avant la syntaxe : toute la ligne.
            if self.reglages.arret == Some(n) {
                return vec![(0..texte.len(), Genre::Arret)].into_iter();
            }
            if self.reglages.points.contains(&n) {
                return vec![(0..texte.len(), Genre::PointArret)].into_iter();
            }
            spans.into_iter()
        }

        fn current_line(&self) -> usize {
            self.ligne
        }
    }
}

/// Les morceaux colores d'une ligne, et si elle finit dans un commentaire /* */.
fn colorer(texte: &str, mut dans_commentaire: bool) -> (Vec<(Range<usize>, Genre)>, bool) {
    let o = texte.as_bytes();
    let mut spans = Vec::new();
    let mut i = 0;
    // Une directive du preprocesseur : la ligne entiere, sauf ses commentaires.
    let directive = !dans_commentaire && texte.trim_start().starts_with('#');
    while i < o.len() {
        if dans_commentaire {
            let fin = texte[i..].find("*/").map(|k| i + k + 2).unwrap_or(o.len());
            spans.push((i..fin, Genre::Commentaire));
            dans_commentaire = fin == o.len() && !texte[i..].contains("*/");
            i = fin;
            continue;
        }
        let c = o[i];
        if texte[i..].starts_with("//") {
            spans.push((i..o.len(), Genre::Commentaire));
            break;
        }
        if texte[i..].starts_with("/*") {
            dans_commentaire = true;
            spans.push((i..i + 2, Genre::Commentaire));
            i += 2;
            continue;
        }
        if c == b'"' || c == b'\'' {
            let mut j = i + 1;
            while j < o.len() && o[j] != c {
                j += if o[j] == b'\\' { 2 } else { 1 };
            }
            let fin = (j + 1).min(o.len());
            spans.push((i..fin, Genre::Chaine));
            i = fin;
            continue;
        }
        if directive {
            let suite = texte[i..].find(['"', '/']).map(|k| i + k).unwrap_or(o.len());
            let fin = if suite == i { i + 1 } else { suite };
            spans.push((i..fin, Genre::Preprocesseur));
            i = fin;
            continue;
        }
        if c.is_ascii_digit() {
            let mut j = i;
            while j < o.len() && (o[j].is_ascii_alphanumeric() || o[j] == b'.') {
                j += 1;
            }
            spans.push((i..j, Genre::Nombre));
            i = j;
            continue;
        }
        if c.is_ascii_alphabetic() || c == b'_' {
            let mut j = i;
            while j < o.len() && (o[j].is_ascii_alphanumeric() || o[j] == b'_') {
                j += 1;
            }
            let mot = &texte[i..j];
            let suivi_de_parenthese = texte[j..].trim_start().starts_with('(');
            let genre = if MOTS_CLES.contains(&mot) {
                Some(Genre::MotCle)
            } else if TYPES.contains(&mot) || mot.ends_with("_t") {
                Some(Genre::Type)
            } else if mot.len() > 1 && mot.chars().all(|c| c.is_ascii_uppercase() || c.is_ascii_digit() || c == '_') {
                Some(Genre::Macro)
            } else if suivi_de_parenthese {
                Some(Genre::Fonction)
            } else {
                None
            };
            if let Some(g) = genre {
                spans.push((i..j, g));
            }
            i = j;
            continue;
        }
        // Un caractere hors ASCII : on avance d'un caractere entier.
        i += texte[i..].chars().next().map(|c| c.len_utf8()).unwrap_or(1);
    }
    (spans, dans_commentaire)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn genres(t: &str) -> Vec<(&str, Genre)> {
        colorer(t, false).0.into_iter().map(|(r, g)| (&t[r], g)).collect()
    }

    #[test]
    fn mots_cles_types_chaines_commentaires() {
        assert_eq!(
            genres("static int x = gpio_get_level(PIN_MAITRE); // fin"),
            [
                ("static", Genre::MotCle),
                ("int", Genre::Type),
                ("gpio_get_level", Genre::Fonction),
                ("PIN_MAITRE", Genre::Macro),
                ("// fin", Genre::Commentaire)
            ]
        );
        assert_eq!(genres("ESP_LOGI(TAG, \"a \\\" b\");")[2], ("\"a \\\" b\"", Genre::Chaine));
        assert_eq!(genres("#include \"esp_log.h\""), [("#include ", Genre::Preprocesseur), ("\"esp_log.h\"", Genre::Chaine)]);
    }

    #[test]
    fn un_commentaire_sur_plusieurs_lignes() {
        let (s, suite) = colorer("x = 1; /* debut", false);
        assert!(suite && s.last().unwrap().1 == Genre::Commentaire);
        let (s, suite) = colorer("fin */ y = 2;", true);
        assert!(!suite);
        assert_eq!(s[0], (0..6, Genre::Commentaire));
    }
}
