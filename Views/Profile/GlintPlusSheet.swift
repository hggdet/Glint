import SwiftUI

@MainActor
struct GlintPlusSheet: View {
    @Bindable var model: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = StoreKitSubscriptionService.monthlyProductID

    private var selectedProduct: SubscriptionProduct? {
        model.products.first(where: { $0.id == selectedProductID }) ?? model.products.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(GlintPalette.accent.gradient)
                        .frame(width: 88, height: 88)
                        .glassEffect(.regular, in: Circle())
                        .accessibilityHidden(true)

                    VStack(spacing: 7) {
                        Text("plus.title")
                            .font(.largeTitle.bold())
                        Text("plus.tagline")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label("plus.feature.shapes", systemImage: "star.circle.fill")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if model.tier == .glintPlus {
                        Label("plus.active", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                    } else {
                        plans
                    }

                    if model.isMockSubscriptionService {
                        Text("plus.demo.notice")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("plus.subscription.terms")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorKey = model.plusErrorKey {
                        Text(LocalizedStringKey(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let noticeKey = model.plusNoticeKey {
                        Text(LocalizedStringKey(noticeKey))
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if model.tier != .glintPlus {
                        Button {
                            guard let selectedProduct else { return }
                            Task {
                                await model.purchase(productID: selectedProduct.id)
                                if model.tier == .glintPlus { dismiss() }
                            }
                        } label: {
                            HStack {
                                if model.isProcessingPurchase { ProgressView().tint(.white) }
                                Text("plus.subscribe")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(model.isProcessingPurchase || model.isLoadingPlans || selectedProduct == nil)
                    }

                    Button("plus.restore") {
                        Task { await model.restorePurchases() }
                    }
                    .buttonStyle(.glass)
                    .disabled(model.isProcessingPurchase)
                }
                .padding(22)
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle("plus.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .task { await model.loadPlans() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var plans: some View {
        if model.isLoadingPlans && model.products.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(20)
        } else if model.products.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("plus.error.productsUnavailable")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("auth.retry.button") { Task { await model.loadPlans() } }
                    .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 10) {
                ForEach(model.products) { product in
                    Button { selectedProductID = product.id } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedProductID == product.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selectedProductID == product.id ? GlintPalette.accent : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.period == .monthly ? "plus.plan.monthly" : "plus.plan.yearly")
                                    .font(.headline)
                                Text(product.displayPrice)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(product.period == .monthly ? "plus.period.month" : "plus.period.year")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(15)
                        .background(selectedProductID == product.id ? GlintPalette.accent.opacity(0.11) : GlintPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selectedProductID == product.id ? GlintPalette.accent : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedProductID == product.id ? .isSelected : [])
                }
            }
        }
    }
}
