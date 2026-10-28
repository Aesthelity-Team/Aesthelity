//
//  ProductArchHeroView.swift
//  Aesthelity
//
//  Archway niche illustration featuring illuminated architectural portal and serum bottle.
//

import SwiftUI

public struct ProductArchHeroView: View {
    public let product: ProductDetailItem
    
    public init(product: ProductDetailItem) {
        self.product = product
    }
    
    public var body: some View {
        ZStack {
            // Warm beige canvas inside the card
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90),
                    Color(red: 0.94, green: 0.89, blue: 0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Architectural Glowing Archway Niche
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    // Outer glowing arch backdrop
                    ArchShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color(red: 0.99, green: 0.94, blue: 0.87)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 156, height: 180)
                        .shadow(color: Color.white.opacity(0.8), radius: 10, x: 0, y: 0)
                        .overlay(
                            ArchShape()
                                .stroke(Color.white.opacity(0.9), lineWidth: 8)
                        )
                    
                    // Circular stone pedestal
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.97, green: 0.95, blue: 0.92),
                                    Color(red: 0.90, green: 0.86, blue: 0.81)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 124, height: 26)
                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
                        .offset(y: 8)
                    
                    // Serum Dropper Bottle
                    cosmeticBottleView
                        .offset(y: -4)
                }
            }
            .offset(y: 8)
        }
        .frame(width: 240, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .stroke(Color(red: 0.49, green: 0.51, blue: 0.74), lineWidth: 9) // Periwinkle frame
        )
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
    }
    
    // Procedural Cosmetic Bottle View
    private var cosmeticBottleView: some View {
        VStack(spacing: 0) {
            // Dropper Bulb
            Capsule()
                .fill(Color(white: 0.96))
                .frame(width: 18, height: 18)
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            
            // Dropper Collar
            VStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.92))
                    .frame(width: 22, height: 10)
                
                Rectangle()
                    .fill(Color(white: 0.88))
                    .frame(width: 24, height: 2)
            }
            
            // Dropper Neck
            Rectangle()
                .fill(Color(white: 0.82))
                .frame(width: 14, height: 3)
            
            // Bottle Body
            ZStack {
                // Amber/warm serum glass
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.99, green: 0.96, blue: 0.92),
                                Color(red: 0.97, green: 0.89, blue: 0.79),
                                Color(red: 0.94, green: 0.84, blue: 0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 58, height: 68)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
                
                // Cosmetic Label
                VStack(spacing: 2) {
                    Text(product.brand.uppercased().prefix(9))
                        .font(.system(size: 6, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                    
                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.4))
                            .frame(width: 28, height: 1.5)
                        
                        Text("10% Glow Serum")
                            .font(.system(size: 4, weight: .medium))
                            .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                    }
                    
                    VStack(spacing: 1.2) {
                        Rectangle()
                            .fill(Color(red: 0.26, green: 0.16, blue: 0.11).opacity(0.2))
                            .frame(width: 32, height: 1)
                        Rectangle()
                            .fill(Color(red: 0.26, green: 0.16, blue: 0.11).opacity(0.2))
                            .frame(width: 24, height: 1)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
                .frame(width: 44, height: 42)
                .background(Color(red: 0.98, green: 0.93, blue: 0.85).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(red: 0.88, green: 0.82, blue: 0.74), lineWidth: 0.5)
                )
            }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 3)
    }
}

// MARK: - Arch Shape Helper

struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2.0
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}
