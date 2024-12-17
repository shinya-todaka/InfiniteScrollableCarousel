//
//  InfiniteScrollableCarousel.swift
//
//  Created by 戸高 新也 on 2024/05/26.
//  Copyright © 2024 YUMEMI. All rights reserved.
//

import SwiftUI

struct InfiniteScrollableCarousel<Item, Content: View>: UIViewRepresentable {
    let items: [Item]
    @Binding var currentIndex: Int
    let timeInterval: Double
    let content: (Item) -> Content
    
    @State private var dummyPageIndex: Int = 0 {
        didSet {
            self.currentIndex = dummyPageIndex % items.count
        }
    }
    
    private var dummyPageCount: Int {
        items.count * 2
    }
    
    private var dummyItems: [Item] {
        items + items
    }

    init(items: [Item], currentIndex: Binding<Int>, timeInterval: Double, content: @escaping (Item) -> Content) {
        self.items = items
        self.timeInterval = timeInterval
        self._currentIndex = currentIndex
        self.content = content
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.alwaysBounceHorizontal = true
        scrollView.decelerationRate = .fast
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = context.coordinator
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        
        var hostingControllers: [UIViewController] = []
        
        for item in dummyItems {
            let hosting = UIHostingController(rootView: content(item))
            hosting.safeAreaRegions = []
            stackView.addArrangedSubview(hosting.view)
            hostingControllers.append(hosting)
        }
        
        context.coordinator.hostingControllers = hostingControllers
        context.coordinator.scrollView = scrollView
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: Double(dummyPageCount)),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            stackView.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) { }
    
}

extension InfiniteScrollableCarousel {
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: InfiniteScrollableCarousel<Item, Content>
        weak var scrollView: UIScrollView?
        var hostingControllers: [UIViewController] = []
        var timer: Timer?
        
        init(parent: InfiniteScrollableCarousel<Item, Content>) {
            self.parent = parent

            super.init()
            
            initializeTimer()
        }
        
        private func initializeTimer() {
            self.timer = Timer.scheduledTimer(timeInterval: parent.timeInterval, target: self, selector: #selector(slideToNextPage), userInfo: nil, repeats: true)
        }
        
        @objc private func slideToNextPage() {
            guard let scrollView else { return }
            let targetContentOffsetX = Double(parent.dummyPageIndex + 1) * scrollView.frame.width
            scrollView.setContentOffset(.init(x: targetContentOffsetX, y: scrollView.contentOffset.y), animated: true)
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if velocity.x == 0.0 {
                let index = round(scrollView.contentOffset.x / scrollView.frame.width)
                
                targetContentOffset.pointee.x = index * scrollView.frame.width
                
            } else {
                let nextIndex = velocity.x > 0.0 ? parent.dummyPageIndex + 1 : parent.dummyPageIndex - 1
                
                targetContentOffset.pointee.x = Double(nextIndex) * scrollView.frame.width
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateContentOffset(of: scrollView)
            
            timer?.invalidate()
            initializeTimer()
        }
        
        private func updateContentOffset(of scrollView: UIScrollView) {
            if scrollView.contentOffset.x >= (scrollView.frame.width * Double(parent.items.count * 2 - 1)) {
                
                scrollView.setContentOffset(.init(x: scrollView.frame.width * Double(parent.items.count - 1), y: scrollView.contentOffset.y), animated: false)
                
                self.parent.dummyPageIndex = parent.items.count - 1
                
            } else if scrollView.contentOffset.x < 0 {
                
                scrollView.setContentOffset(.init(x: scrollView.frame.width * Double(parent.items.count), y: scrollView.contentOffset.y), animated: false)
                
                self.parent.dummyPageIndex = parent.items.count
                
            } else {
                
                let index = round(scrollView.contentOffset.x / scrollView.frame.width)
                
                self.parent.dummyPageIndex = Int(index)
            }
        }
    }
}

#Preview("aspect ratio fit content") {
    let colors: [Color] = [.red, .blue, .green]
    
    return InfiniteScrollableCarousel(
        items: colors,
        currentIndex: .constant(0),
        timeInterval: 5.0,
        content: { color in
            color
                .aspectRatio(2.0, contentMode: .fit)
        }
    )
}


#Preview("aspect ratio fill content") {
    let colors: [Color] = [.red, .blue, .green]
    
    return InfiniteScrollableCarousel(
        items: colors,
        currentIndex: .constant(0),
        timeInterval: 5.0,
        content: { color in
            // aspectRatio fill でclipする場合は使う側で対応する必要があります
            ZStack {
                color
                    .aspectRatio(2.0, contentMode: .fill)
                    .frame(minWidth: 0, minHeight: 0)
            }
            .clipped()
           
        }
    )
}

