//
//  ChartFrameView.swift
//  ChartTest
//
//  【View】メイン・サブ全体を囲む外枠。線を描く辺を選べる(横画面では左と上の線を描かない)。
//
//  線の色・太さ・描く辺は StockChartStyle(borderColor・borderWidth・borderEdges)で決め、StockChartView が渡す。
//

import UIKit

/// 外枠の線を、選んだ辺にだけ描くView。線はこのViewの内側に描く(layer.border と同じ)
final class ChartFrameView: UIView {

    /// 線を描く辺
    var edges: UIRectEdge = .all {
        didSet {
            self.setNeedsDisplay()
        }
    }
    /// 線の色
    var lineColor: UIColor = .black {
        didSet {
            self.setNeedsDisplay()
        }
    }
    /// 線の太さ
    var lineWidth: CGFloat = 1 {
        didSet {
            self.setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear  // 線だけを描く
        self.isOpaque = false
        self.contentMode = .redraw     // 大きさが変わったら描き直す
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        // 線の中心を、太さの半分だけ内側に置く(線がこのViewの内側に収まる)
        let lineRect = self.bounds.insetBy(dx: self.lineWidth / 2, dy: self.lineWidth / 2)
        let path = UIBezierPath()
        if self.edges.contains(.top) {
            path.move(to: CGPoint(x: self.bounds.minX, y: lineRect.minY))
            path.addLine(to: CGPoint(x: self.bounds.maxX, y: lineRect.minY))
        }
        if self.edges.contains(.bottom) {
            path.move(to: CGPoint(x: self.bounds.minX, y: lineRect.maxY))
            path.addLine(to: CGPoint(x: self.bounds.maxX, y: lineRect.maxY))
        }
        if self.edges.contains(.left) {
            path.move(to: CGPoint(x: lineRect.minX, y: self.bounds.minY))
            path.addLine(to: CGPoint(x: lineRect.minX, y: self.bounds.maxY))
        }
        if self.edges.contains(.right) {
            path.move(to: CGPoint(x: lineRect.maxX, y: self.bounds.minY))
            path.addLine(to: CGPoint(x: lineRect.maxX, y: self.bounds.maxY))
        }
        path.lineWidth = self.lineWidth
        self.lineColor.setStroke()
        path.stroke()
    }
}
