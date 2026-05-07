//
//  RecipeSuggestionView.swift
//  Spichr
//

import SwiftUI
import CoreData

struct RecipeSuggestionView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @State private var matches: [RecipeMatch] = []
    @State private var addedIngredients: Set<String> = []

    private let repository = FoodItemRepository()

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("recipes_none_title"),
                        systemImage: "fork.knife.circle",
                        description: Text(LocalizedStringKey("recipes_none_desc"))
                    )
                } else {
                    List {
                        Section {
                            Label {
                                Text(LocalizedStringKey("recipes_language_notice"))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } icon: {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        ForEach(matches) { match in
                            RecipeMatchRow(match: match, addedIngredients: $addedIngredients) { ingredient in
                                addToShoppingList(ingredient)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(LocalizedStringKey("recipes_title"))
            .navigationBarTitleDisplayMode(.large)
            .onAppear { loadMatches() }
        }
    }

    private func loadMatches() {
        let expiring = repository.fetchExpiringItems(withinDays: 3)
        let allStock = repository.fetchStockItems()
        // Recipes are matched against all stock, triggered by expiring items
        let relevant = expiring.isEmpty ? allStock : allStock
        matches = matchRecipes(to: relevant).filter { $0.matchScore > 0 }
    }

    private func addToShoppingList(_ ingredient: String) {
        repository.createItem(
            name: ingredient.prefix(1).uppercased() + ingredient.dropFirst(),
            isInStock: false
        )
        addedIngredients.insert(ingredient)
    }
}

// MARK: - Recipe Row

private struct RecipeMatchRow: View {
    let match: RecipeMatch
    @Binding var addedIngredients: Set<String>
    let onAddIngredient: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Text(match.recipe.emoji)
                        .font(.largeTitle)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.recipe.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack(spacing: 4) {
                            Text("\(match.availableIngredients.count)/\(match.recipe.ingredients.count)")
                                .font(.caption)
                                .foregroundStyle(match.matchScore >= 0.8 ? .green : .orange)
                            Text(LocalizedStringKey("recipes_ingredients_label"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: match.matchScore)
                            .tint(match.matchScore >= 0.8 ? .green : .orange)
                    }

                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(match.recipe.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    if !match.availableIngredients.isEmpty {
                        Text(LocalizedStringKey("recipes_have_label"))
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                        FlowRow(items: match.availableIngredients) { ing in
                            IngredientChip(name: ing, state: .available)
                        }
                    }

                    if !match.missingIngredients.isEmpty {
                        Text(LocalizedStringKey("recipes_missing_label"))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        FlowRow(items: match.missingIngredients) { ing in
                            Button {
                                onAddIngredient(ing)
                            } label: {
                                IngredientChip(
                                    name: ing,
                                    state: addedIngredients.contains(ing) ? .added : .missing
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Ingredient Chip

private enum ChipState { case available, missing, added }

private struct IngredientChip: View {
    let name: String
    let state: ChipState

    var body: some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(borderColor, lineWidth: state == .missing ? 1 : 0))
    }

    private var background: Color {
        switch state {
        case .available: return .green.opacity(0.15)
        case .missing:   return .clear
        case .added:     return .blue.opacity(0.15)
        }
    }

    private var foreground: Color {
        switch state {
        case .available: return .green
        case .missing:   return .secondary
        case .added:     return .blue
        }
    }

    private var borderColor: Color {
        state == .missing ? Color(.separator) : .clear
    }
}

// MARK: - FlowRow helper

private struct FlowRow<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        // Simple wrapping layout using LazyVGrid with adaptive columns
        let cols = [GridItem(.adaptive(minimum: 72, maximum: 200), spacing: 6)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in content(item) }
        }
    }
}

#Preview {
    RecipeSuggestionView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
