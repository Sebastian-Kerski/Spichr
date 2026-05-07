//
//  RecipeData.swift
//  Spichr
//

import Foundation

struct Recipe: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let ingredients: [String]
    let description: String
}

// 20 common pantry-friendly recipes; ingredients are lowercase for matching.
let bundledRecipes: [Recipe] = [
    Recipe(name: "Pasta Aglio e Olio", emoji: "🍝",
           ingredients: ["pasta", "garlic", "olive oil", "parsley", "parmesan"],
           description: "Classic Italian pasta with garlic and olive oil."),
    Recipe(name: "Scrambled Eggs", emoji: "🍳",
           ingredients: ["eggs", "butter", "milk", "salt"],
           description: "Fluffy scrambled eggs with butter."),
    Recipe(name: "Banana Pancakes", emoji: "🥞",
           ingredients: ["banana", "eggs", "flour", "milk", "butter"],
           description: "Sweet banana pancakes — great for overripe bananas."),
    Recipe(name: "Tomato Soup", emoji: "🍅",
           ingredients: ["tomato", "onion", "garlic", "olive oil", "cream"],
           description: "Smooth roasted tomato soup."),
    Recipe(name: "Cheese Omelette", emoji: "🧀",
           ingredients: ["eggs", "cheese", "butter", "salt", "pepper"],
           description: "Quick omelette with melted cheese."),
    Recipe(name: "Vegetable Stir-Fry", emoji: "🥦",
           ingredients: ["broccoli", "carrot", "garlic", "soy sauce", "ginger", "sesame oil"],
           description: "Quick vegetable stir-fry."),
    Recipe(name: "Chicken Soup", emoji: "🍲",
           ingredients: ["chicken", "carrot", "celery", "onion", "garlic", "broth"],
           description: "Hearty homemade chicken soup."),
    Recipe(name: "Yogurt Parfait", emoji: "🥣",
           ingredients: ["yogurt", "banana", "honey", "granola"],
           description: "Layered yogurt parfait for breakfast."),
    Recipe(name: "Avocado Toast", emoji: "🥑",
           ingredients: ["bread", "avocado", "lemon", "salt", "pepper"],
           description: "Simple avocado on toast."),
    Recipe(name: "Rice and Beans", emoji: "🫘",
           ingredients: ["rice", "beans", "onion", "garlic", "cumin", "olive oil"],
           description: "Protein-packed rice and beans."),
    Recipe(name: "French Toast", emoji: "🍞",
           ingredients: ["bread", "eggs", "milk", "butter", "cinnamon", "sugar"],
           description: "Classic French toast."),
    Recipe(name: "Garlic Bread", emoji: "🧄",
           ingredients: ["bread", "butter", "garlic", "parsley"],
           description: "Crispy garlic bread — great with soup."),
    Recipe(name: "Caprese Salad", emoji: "🥗",
           ingredients: ["tomato", "mozzarella", "basil", "olive oil", "balsamic"],
           description: "Simple Italian salad."),
    Recipe(name: "Spaghetti Bolognese", emoji: "🍝",
           ingredients: ["pasta", "ground beef", "tomato", "onion", "garlic", "olive oil", "parmesan"],
           description: "Classic meat sauce pasta."),
    Recipe(name: "Fried Rice", emoji: "🍚",
           ingredients: ["rice", "eggs", "soy sauce", "garlic", "onion", "carrot"],
           description: "Quick fried rice with eggs."),
    Recipe(name: "Potato Soup", emoji: "🥔",
           ingredients: ["potato", "onion", "garlic", "cream", "butter", "broth"],
           description: "Creamy potato soup."),
    Recipe(name: "Apple Crumble", emoji: "🍎",
           ingredients: ["apple", "butter", "flour", "sugar", "cinnamon", "oats"],
           description: "Warm apple crumble with oat topping."),
    Recipe(name: "Lentil Stew", emoji: "🥣",
           ingredients: ["lentil", "tomato", "onion", "garlic", "cumin", "carrot"],
           description: "Hearty lentil stew."),
    Recipe(name: "Grilled Cheese", emoji: "🧀",
           ingredients: ["bread", "cheese", "butter"],
           description: "Simple grilled cheese sandwich."),
    Recipe(name: "Banana Bread", emoji: "🍌",
           ingredients: ["banana", "flour", "eggs", "butter", "sugar", "baking soda"],
           description: "Moist banana bread — ideal for overripe bananas."),
]

// MARK: - Matching Logic

struct RecipeMatch: Identifiable {
    let id = UUID()
    let recipe: Recipe
    let availableIngredients: [String]
    let missingIngredients: [String]

    var matchScore: Double {
        guard !recipe.ingredients.isEmpty else { return 0 }
        return Double(availableIngredients.count) / Double(recipe.ingredients.count)
    }
}

// MARK: - Normalization

// Strips leading quantity expressions ("500g ", "2 ", "1,5 l ", "3x ") before
// lowercasing so locale pantry names like "500g Mehl" match the ingredient "flour".
private let quantityPrefixPattern: NSRegularExpression? = try? NSRegularExpression(
    pattern: #"^\d[\d.,]*\s*(g|kg|ml|cl|dl|l|oz|lbs?|x|stk|pcs|el|tl|cups?|tbsp|tsp|pack|pkg|st[üu]ck?)?\s+"#,
    options: .caseInsensitive
)

private func normalizedForMatching(_ s: String) -> String {
    var result = s.lowercased().trimmingCharacters(in: .whitespaces)
    if let pattern = quantityPrefixPattern {
        let range = NSRange(result.startIndex..., in: result)
        result = pattern.stringByReplacingMatches(in: result, range: range, withTemplate: "")
    }
    result = result
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\b(liters?|litres?)\\b", with: "l", options: .regularExpression)
    return result
}

// MARK: - Ingredient Aliases
//
// Keys are the canonical English ingredient strings from bundledRecipes (lowercase).
// Values are alternate names in all 18 supported locales.
// Aliases shorter than 3 Latin characters are omitted to avoid substring false positives.
// CJK single-character aliases are acceptable due to script specificity.

private let ingredientAliases: [String: [String]] = [

    "pasta": [
        // DE FR ES IT PT NL PL SV DA FI
        "nudeln", "pâtes", "fideos", "spaghetti", "massa", "macarrão", "noedels", "makaron",
        // JA KO ZH RU TR AR UK
        "パスタ", "파스타", "意面", "意大利面", "макароны", "makarna", "معكرونة", "макарони",
    ],

    "garlic": [
        "knoblauch", "ail", "ajo", "aglio", "alho", "knoflook", "czosnek", "vitlök",
        "hvidløg", "valkosipuli",
        "にんにく", "마늘", "大蒜", "чеснок", "sarımsak", "ثوم", "часник",
    ],

    "olive oil": [
        "olivenöl", "huile d'olive", "aceite de oliva", "olio d'oliva", "azeite",
        "olijfolie", "oliwa z oliwek", "olivolja", "olivenolie", "oliiviöljy",
        "オリーブオイル", "올리브 오일", "橄榄油", "оливковое масло", "zeytinyağı",
        "زيت زيتون", "оливкова олія",
    ],

    "parsley": [
        "petersilie", "persil", "perejil", "prezzemolo", "peterselie", "pietruszka",
        "persilja", "persille", "persilja",
        // PT "salsa" means parsley — safe in a food-item context
        "salsa de perejil",
        "パセリ", "파슬리", "欧芹", "петрушка", "maydanoz", "بقدونس", "петрушка",
    ],

    "parmesan": [
        "parmesano", "parmigiano", "parmesão", "parmezaan", "parmezan", "parmesaani",
        "パルメザン", "파마산", "帕玛森", "пармезан", "بارميزان", "пармезан",
    ],

    "eggs": [
        "eier", "œufs", "oeufs", "huevos", "huevo", "uova", "uovo", "ovos", "ovo",
        "eieren", "jajka", "jajo", "ägg", "æg", "kananmuna", "munat",
        "卵", "たまご", "달걀", "계란", "鸡蛋", "яйца", "яйцо", "yumurta", "بيض", "яйця", "яйце",
    ],

    "butter": [
        "beurre", "mantequilla", "burro", "manteiga", "boter", "masło", "smör", "smør",
        "voi",
        "バター", "버터", "黄油", "сливочное масло", "tereyağı", "زبدة", "вершкове масло",
    ],

    "milk": [
        "milch", "lait", "leche", "latte", "leite", "melk", "mleko", "mjölk", "mælk",
        "maito",
        "牛乳", "ミルク", "우유", "牛奶", "молоко", "süt", "حليب",
    ],

    "salt": [
        "salz", "sel", "sale", "zout", "sól", "salt", "suola",
        // ES/PT "sal" omitted — 3 chars but appears as prefix in "salsa"
        "塩", "소금", "盐", "соль", "tuz", "ملح", "сіль",
    ],

    "banana": [
        "banane", "plátano", "banan", "banaan", "banaani",
        "バナナ", "바나나", "香蕉", "банан", "muz", "موز",
    ],

    "flour": [
        "mehl", "farine", "harina", "meel", "bloem", "mąka", "mjöl", "mel", "jauho",
        "vehnäjauho",
        "小麦粉", "밀가루", "面粉", "мука", "dqyq", "دقيق", "борошно",
    ],

    "tomato": [
        "tomate", "pomodoro", "tomaat", "pomidor", "tomat", "tomaatti",
        "トマト", "토마토", "番茄", "西红柿", "помидор", "томат", "domates", "طماطم",
    ],

    "onion": [
        "zwiebel", "oignon", "cebolla", "cipolla", "cebola", "cebula", "lök", "løg",
        "sipuli",
        // NL "ui" omitted — 2 chars
        "玉ねぎ", "양파", "洋葱", "лук", "soğan", "بصل", "цибуля",
    ],

    "cream": [
        "sahne", "rahm", "crème", "nata", "crema", "panna", "slagroom", "śmietana",
        "grädde", "fløde", "kerma",
        // NL "room" kept — 4 chars, acceptable
        "room",
        "生クリーム", "생크림", "奶油", "сливки", "krema", "قشدة", "вершки",
    ],

    "cheese": [
        "käse", "fromage", "queso", "formaggio", "queijo", "kaas", "ser", "ost",
        "juusto",
        "チーズ", "치즈", "奶酪", "сыр", "peynir", "جبن", "сир",
    ],

    "pepper": [
        "pfeffer", "poivre", "pimienta", "pepe", "pimenta", "peper", "pieprz", "peppar",
        "peber", "pippuri",
        "こしょう", "ペッパー", "후추", "胡椒", "перец", "karabiber", "biber", "فلفل", "перець",
    ],

    "broccoli": [
        "brokkoli", "brocoli", "brócoli", "brócolis", "brokuły", "parsakaali",
        "ブロッコリー", "브로콜리", "西兰花", "брокколи", "brokoli", "بروكلي", "броколі",
    ],

    "carrot": [
        "karotte", "möhre", "carotte", "zanahoria", "carota", "cenoura", "wortel",
        "marchewka", "morot", "gulerod", "porkkana",
        "にんじん", "당근", "胡萝卜", "морковь", "havuç", "جزر", "морква",
    ],

    "soy sauce": [
        "sojasoße", "sojasosse", "sojasouce", "sauce soja", "salsa de soja",
        "salsa di soia", "molho de soja", "sojasaus", "sos sojowy", "sojasås",
        "sojasovs", "soijakastike",
        "しょうゆ", "醤油", "간장", "酱油", "соевый соус", "soya sosu", "صلصة الصويا",
        "соєвий соус",
    ],

    "ginger": [
        "ingwer", "gingembre", "jengibre", "zenzero", "gengibre", "gember", "imbir",
        "ingefära", "ingefær", "inkivääri",
        "しょうが", "生姜", "생강", "姜", "имбирь", "zencefil", "زنجبيل", "імбир",
    ],

    "sesame oil": [
        "sesamöl", "huile de sésame", "aceite de sésamo", "olio di sesamo",
        "óleo de gergelim", "sesamolie", "olej sezamowy", "sesamolja", "seesamiöljy",
        "ごま油", "참기름", "芝麻油", "кунжутное масло", "susam yağı", "زيت السمسم",
        "кунжутна олія",
    ],

    "chicken": [
        "hähnchen", "hühnchen", "huhn", "poulet", "pollo", "frango", "kip", "kurczak",
        "kyckling", "kylling", "kana",
        "鶏肉", "チキン", "닭고기", "鸡肉", "курица", "tavuk", "دجاج", "курка",
    ],

    "celery": [
        "sellerie", "céleri", "apio", "sedano", "aipo", "selderij", "seler", "selleri",
        "セロリ", "셀러리", "芹菜", "сельдерей", "kereviz", "كرفس", "селера",
    ],

    "broth": [
        "brühe", "fond", "bouillon", "caldo", "brodo", "bulion", "wywar", "buljong",
        "liemi", "lihaliemi",
        "ブイヨン", "だし", "육수", "高汤", "肉汤", "бульон", "et suyu", "مرق", "бульйон",
    ],

    "yogurt": [
        "joghurt", "yaourt", "yogourt", "yogur", "iogurte", "yoghurt", "jogurt",
        "jogurtti",
        "ヨーグルト", "요구르트", "酸奶", "йогурт", "yoğurt", "زبادي",
    ],

    "honey": [
        "honig", "miel", "miele", "honing", "miód", "honung", "honning", "hunaja",
        // PT "mel" and TR "bal" omitted — substring false positives (melancia, balık)
        "はちみつ", "꿀", "蜂蜜", "мёд", "عسل", "мед",
    ],

    "granola": [
        "müsli", "muesli", "musli", "mysli",
        "グラノーラ", "그래놀라", "格兰诺拉", "гранола", "мюсли", "غرانولا",
    ],

    "bread": [
        "brot", "pain", "pane", "brood", "chleb", "bröd", "brød", "leipä",
        // ES "pan" and PT "pão" kept — 3 chars, specific enough in pantry context
        "pan", "pão",
        "パン", "빵", "面包", "хлеб", "ekmek", "خبز", "хліб",
    ],

    "avocado": [
        "avocat", "aguacate", "abacate", "awokado", "avokado",
        "アボカド", "아보카도", "牛油果", "鳄梨", "авокадо", "أفوكادو",
    ],

    "lemon": [
        "zitrone", "citron", "limón", "limone", "limão", "citroen", "cytryna",
        "sitruuna",
        "レモン", "레몬", "柠檬", "лимон", "limon", "ليمون",
    ],

    "rice": [
        "reis", "riz", "arroz", "riso", "rijst", "ryż", "ris", "riisi",
        "米", "ご飯", "쌀", "大米", "рис", "pirinç", "أرز",
    ],

    "beans": [
        "bohnen", "bohne", "haricots", "haricot", "frijoles", "judías", "alubias",
        "fagioli", "fagiolo", "feijão", "bonen", "fasola", "bönor", "bønner", "pavut",
        "豆", "豆子", "콩", "фасоль", "бобы", "fasulye", "فول", "квасоля", "боби",
    ],

    "cumin": [
        "kreuzkümmel", "comino", "cumino", "cominho", "komijn", "kmin", "kminek",
        "spiskummin", "spidskommen", "juustokumina",
        "クミン", "커민", "孜然", "тмин", "зира", "kimyon", "كمون", "кмин", "зіра",
    ],

    "cinnamon": [
        "zimt", "cannelle", "canela", "cannella", "kaneel", "cynamon", "kanel", "kaneli",
        "シナモン", "시나몬", "肉桂", "корица", "tarçın", "قرفة", "кориця",
    ],

    "sugar": [
        "zucker", "sucre", "azúcar", "zucchero", "açúcar", "suiker", "cukier", "socker",
        "sukker", "sokeri",
        "砂糖", "설탕", "糖", "сахар", "şeker", "سكر", "цукор",
    ],

    "mozzarella": [
        "mozzarelle", "モッツァレラ", "모짜렐라", "马苏里拉", "моцарелла", "جبن موزاريلا",
        "моцарела",
    ],

    "basil": [
        "basilikum", "basilic", "albahaca", "basilico", "manjericão", "basilicum",
        "bazylia", "basilika",
        "バジル", "바질", "罗勒", "базилик", "fesleğen", "ريحان", "базилік",
    ],

    "balsamic": [
        "balsamico", "balsamessig", "balsamique", "vinaigre balsamique", "balsámico",
        "vinagre balsámico", "aceto balsamico", "balsâmico", "ocet balsamiczny",
        "balsamvinäger", "balsamiviinietikka",
        "バルサミコ", "발사믹", "意大利香醋", "巴萨米克", "бальзамик", "balzamik",
        "خل البلسميك", "бальзамік",
    ],

    "ground beef": [
        "hackfleisch", "rinderhack", "bœuf haché", "viande hachée", "carne molida",
        "carne picada", "carne macinata", "macinato", "carne moída", "gehakt",
        "mielone", "köttfärs", "hakket oksekød", "jauheliha",
        "ひき肉", "다진 소고기", "牛肉末", "碎牛肉", "говяжий фарш", "фарш", "kıyma",
        "لحم مفروم", "яловичий фарш",
    ],

    "potato": [
        "kartoffel", "pomme de terre", "patata", "papa", "batata", "aardappel",
        "ziemniak", "potatis", "peruna",
        "じゃがいも", "감자", "土豆", "马铃薯", "картофель", "картошка", "patates",
        "بطاطس", "картопля",
    ],

    "apple": [
        "apfel", "pomme", "manzana", "mela", "maçã", "appel", "jabłko", "äpple",
        "æble", "omena",
        "りんご", "사과", "苹果", "яблоко", "elma", "تفاح", "яблуко",
    ],

    "oats": [
        "haferflocken", "hafer", "flocons d'avoine", "avoine", "avena",
        "copos de avena", "fiocchi d'avena", "havermout", "haver", "płatki owsiane",
        "owies", "havregryn", "havre", "kaurahiutaleet", "kaura",
        "オートミール", "귀리", "燕麦", "овсяные хлопья", "овсянка", "yulaf", "شوفان",
        "вівсяні пластівці", "вівсянка",
    ],

    "lentil": [
        "linse", "linsen", "lentille", "lentilles", "lenteja", "lentejas",
        "lenticchia", "lenticchie", "lentilha", "linze", "linzen", "soczewica",
        "lins", "linssi",
        "レンズ豆", "렌틸", "扁豆", "чечевица", "mercimek", "عدس", "сочевиця",
    ],

    "baking soda": [
        "natron", "backpulver", "bicarbonate de soude", "levure chimique", "bicarbonato",
        "levadura", "zuiveringszout", "soda oczyszczona", "bikarbonat", "bakpulver",
        "bagepulver", "ruokasooda", "leivinjauhe",
        "重曹", "ベーキングソーダ", "베이킹소다", "小苏打", "сода", "karbonat",
        "kabartma tozu", "صودا الخبز", "харчова сода",
    ],
]

// Returns all normalized search terms for a given canonical ingredient.
private func aliases(for ingredient: String) -> [String] {
    var terms = [normalizedForMatching(ingredient)]
    if let extras = ingredientAliases[ingredient] {
        terms += extras.map { normalizedForMatching($0) }
    }
    return terms
}

// MARK: - Match

func matchRecipes(to stockItems: [FoodItem]) -> [RecipeMatch] {
    let stockNames = stockItems.map { normalizedForMatching($0.unwrappedName) }

    return bundledRecipes.compactMap { recipe in
        var available: [String] = []
        var missing: [String] = []

        for ingredient in recipe.ingredients {
            let terms = aliases(for: ingredient)
            let found = stockNames.contains { name in
                terms.contains { alias in
                    name.contains(alias) || alias.contains(name)
                }
            }
            if found { available.append(ingredient) } else { missing.append(ingredient) }
        }

        guard !available.isEmpty else { return nil }
        return RecipeMatch(recipe: recipe, availableIngredients: available, missingIngredients: missing)
    }
    .sorted { $0.matchScore > $1.matchScore }
}
