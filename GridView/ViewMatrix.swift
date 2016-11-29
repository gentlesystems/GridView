//
//  ViewMatrix.swift
//  GridView
//
//  Created by Kyohei Ito on 2016/11/25.
//  Copyright © 2016年 Kyohei Ito. All rights reserved.
//

import UIKit

struct ViewMatrix: Countable {
    private let isInfinitable: Bool
    private let widths: [CGWidth]?
    private let heights: [[CGHeight]]
    private let visibleSize: CGSize?
    private let viewFrame: CGRect
    private let aroundInset: AroundInsets
    
    let validityContentRect: CGRect
    let contentSize: CGSize
    let contentInset: UIEdgeInsets
    var count: Int {
        return heights.count
    }
    
    func convert(_ offsetX: CGFloat, from matrix: ViewMatrix) -> CGFloat {
        if isInfinitable {
            let oldLeftScale = matrix.aroundInset.left.width / matrix.viewFrame.width
            let oldAllScale = (matrix.aroundInset.left.width + matrix.aroundInset.right.width + matrix.viewFrame.width) / matrix.viewFrame.width
            
            let leftScale = aroundInset.left.width / viewFrame.width
            let diffScale = leftScale - oldLeftScale
            
            let newWidth = validityContentRect.width + viewFrame.width * oldAllScale
            let oldWidth = matrix.contentSize.width
            return newWidth * offsetX / oldWidth + viewFrame.width * diffScale
        } else {
            return contentSize.width * offsetX / matrix.contentSize.width
        }
    }
    
    init() {
        self.init(widths: nil, heights: [], viewFrame: .zero, contentSize: .zero, superviewSize: nil, isInfinitable: false)
    }
    
    init(matrix: ViewMatrix, widths: [CGWidth]? = nil, viewFrame: CGRect, contentSize: CGSize, superviewSize: CGSize?) {
        self.init(widths: widths ?? matrix.widths, heights: matrix.heights, viewFrame: viewFrame, contentSize: contentSize, superviewSize: superviewSize, isInfinitable: matrix.isInfinitable)
    }
    
    init(widths: [CGWidth]?,  heights: [[CGHeight]], viewFrame: CGRect, contentSize: CGSize, superviewSize: CGSize?, isInfinitable: Bool) {
        self.widths = widths
        self.heights = heights
        self.viewFrame = viewFrame
        self.visibleSize = superviewSize
        self.isInfinitable = isInfinitable
        
        let parentSize = superviewSize ?? .zero
        if isInfinitable {
            let inset = AroundInsets(parentSize: parentSize, frame: viewFrame)
            self.aroundInset = inset
            
            let allWidth = inset.left.width + inset.right.width + viewFrame.width
            self.validityContentRect = CGRect(origin: CGPoint(x: inset.left.width - viewFrame.minX, y: 0), size: contentSize)
            self.contentSize = CGSize(width: contentSize.width + allWidth, height: contentSize.height)
            self.contentInset = UIEdgeInsets(top: -viewFrame.minY, left: -inset.left.width, bottom: -parentSize.height + viewFrame.maxY, right: -inset.right.width)
        } else {
            self.aroundInset = .zero
            self.validityContentRect = CGRect(origin: .zero, size: contentSize)
            self.contentSize = contentSize
            self.contentInset = UIEdgeInsets(top: -viewFrame.minY, left: -viewFrame.minX, bottom: -parentSize.height + viewFrame.maxY, right: -parentSize.width + viewFrame.maxX)
        }
    }
    
    private func heightsForSection(_ section: Int) -> [CGHeight] {
        if section < 0 || section >= heights.count {
            return []
        }
        return heights[section]
    }
    
    private func heightForRow(at indexPath: IndexPath) -> CGHeight {
        let heights = heightsForSection(indexPath.section)
        if indexPath.row < 0 || indexPath.row >= heights.count {
            return .zero
        }
        return heights[indexPath.row]
    }
    
    private func offsetXForSection(_ section: Int) -> CGFloat {
        guard let widths = widths else {
            return 0
        }
        
        if section < 0 {
            return -validityContentRect.width
        } else if section >= widths.count {
            return validityContentRect.width
        } else {
            return 0
        }
    }
    
    private func widthForSection(_ section: Int) -> CGWidth {
        var width: CGWidth
        if let widths = widths {
            let absSection = abs(section)
            width = widths[absSection]
            width.x += offsetXForSection(section)
        } else {
            width = CGWidth(x: viewFrame.width * CGFloat(section), width: viewFrame.width)
        }
        
        return width
    }
    
    func rectForRow(at indexPath: IndexPath, threshold: Threshold = .in) -> CGRect {
        let height = heightForRow(at: indexPath)
        var rect = CGRect(height: height)
        rect.horizontal = widthForSection(indexPath.section)
        rect.origin.x += aroundInset.left.width
        
        switch threshold {
        case .below:
            rect.origin.x -= validityContentRect.width
        case .above:
            rect.origin.x += validityContentRect.width
        default:
            break
        }
        
        return rect
    }
    
    func indexPathForRow(at point: CGPoint) -> IndexPath {
        let absPoint = CGPoint(x: point.x - aroundInset.left.width, y: point.y)
        let absSection = abs(section(at: absPoint))
        let row = indexForRow(at: absPoint, in: absSection)
        return IndexPath(row: row, section: absSection)
    }
    
    private func section(at point: CGPoint) -> Int {
        guard let widths = widths else {
            return Int(floor(point.x / viewFrame.width))
        }
        
        var section = 0
        if point.x < 0 {
            section += widths.count
        } else if point.x >= validityContentRect.width {
            section -= widths.count
        }
        
        var point = point
        point.x += offsetXForSection(section)
        
        for index in (0..<widths.count) {
            let width = widths[index]
            if width.x <= point.x && width.maxX > point.x {
                return index - section
            }
        }
        
        return 0
    }
    
    private func indexForRow(at point: CGPoint, in section: Int) -> Int {
        let step = 100
        let heights = heightsForSection(section)
        
        for index in stride(from: 0, to: heights.count, by: step) {
            let next = index + step
            guard heights.count <= next || heights[next].maxY > point.y else {
                continue
            }
            
            for offset in (index..<heights.count) {
                guard heights[offset].maxY > point.y else {
                    continue
                }
                
                return offset
            }
            
            return index
        }
        
        return 0
    }
    
    func indexesForVisibleSection(at point: CGPoint) -> [Int] {
        var sections: [Int] = []
        guard let visibleSize = visibleSize else {
            return sections
        }
        
        let visibleRect = CGRect(origin: CGPoint(x: point.x - aroundInset.left.width, y: 0), size: visibleSize)
        let index = section(at: visibleRect.origin)
        
        var frame = CGRect(origin: .zero, size: viewFrame.size)
        for offset in (0..<count) {
            let section = offset + index
            frame.horizontal = widthForSection(section)
            
            if visibleRect.intersects(frame) {
                sections.append(section)
            } else {
                break
            }
        }
        
        return sections
    }
    
    func indexesForVisibleRow(at point: CGPoint, in section: Int) -> [Int] {
        var rows: [Int] = []
        guard let visibleSize = visibleSize else {
            return rows
        }
        
        let visibleRect = CGRect(origin: CGPoint(x: 0, y: point.y), size: visibleSize)
        let absSection: Int
        if isInfinitable {
            absSection = abs(section)
        } else {
            absSection = section
        }
        
        let index = indexForRow(at: visibleRect.origin, in: absSection)
        let heights = heightsForSection(absSection)
        
        var rect: CGRect = .zero
        rect.size.width = widthForSection(section).width
        for row in (index..<heights.count) {
            let height = heights[row]
            rect.size.height = height.height
            rect.origin.y = height.y
            
            if visibleRect.intersects(rect) {
                rows.append(row)
            } else {
                break
            }
        }
        
        return rows
    }
}
