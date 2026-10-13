//
//  LandscapeChartTransition.swift
//  ChartTest
//
//  【View】横画面のチャート(LandscapeChartViewController)を開く・閉じるときの、回転のアニメーション。
//
//  横向きだけの画面を present・dismiss すると、UIKit は画面の向きを一瞬で切り替え、回転のアニメーションは付けない。
//  そこで、向きが切り替わる前の見た目をスナップショットに撮っておき、向きが切り替わったあとに、
//  そのスナップショットと次の画面を一緒に回しながら入れ替えて、端末を回したときの iOS の回転アニメーションと同じ見た目にする。
//
//   開くとき                                          閉じるとき
//   ┌────┐ 開く前の画面のスナップショット(縦)         ┌────────┐ 横画面のスナップショット
//   │    │   ↓ 横画面と一緒に 90° 回しながら            │        │   ↓ 開く前の画面と一緒に 90° 回しながら
//   └────┘   ↓ 横画面にフェード                        └────────┘   ↓ 開く前の画面にフェード
//   ┌────────┐ 横画面                                  ┌────┐ 開く前の画面(縦)
//   │        │                                         │    │
//   └────────┘                                         └────┘
//
//  ・スナップショットは、UIKit がアニメーションを頼んできた時点(向きが切り替わる前)に撮る
//  ・回す向きは、横向きの向き(landscapeRight / landscapeLeft)に合わせる(端末を左右どちらに傾けても、端末と同じ向きに回る)
//  ・画面の向きが変わらなかったとき(iPad の画面分割中・iPhone Duo の内側の画面など)は、回さずにフェードだけにする
//  ・LandscapeChartViewController が transitioningDelegate に設定して使う(instantiate)。呼び出し側は
//    present(animated: true) / dismiss(animated: true) を呼ぶだけでよい
//

import UIKit

/// 横画面のチャートを開く・閉じるときのアニメーションを UIKit に渡す
final class LandscapeChartTransition: NSObject, UIViewControllerTransitioningDelegate {

    func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // この時点では画面の向きはまだ切り替わっていないので、開く前の画面をそのままの見た目で撮っておく。
        // 横向きの向きは、横画面が開く予定の向き(アニメーションの時点では、シーンの向きがまだ変わっていないことがあるため)
        return RotatingAnimator(oldView: presenting.view,
                                landscapeOrientation: presented.preferredInterfaceOrientationForPresentation)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // 閉じる前の横画面をそのままの見た目で撮っておく。横向きの向きは、今のシーンの向き
        var orientation = UIInterfaceOrientation.unknown
        if let windowScene = dismissed.view.window?.windowScene {
            orientation = windowScene.effectiveGeometry.interfaceOrientation
        }
        return RotatingAnimator(oldView: dismissed.view, landscapeOrientation: orientation)
    }
}

// MARK: - 回転のアニメーション本体

/// 向きが切り替わる前の見た目(スナップショット)と次の画面を、一緒に回しながら入れ替える
private final class RotatingAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    /// アニメーションの秒数(端末を回したときの iOS の回転と同じくらい)
    private static let duration: TimeInterval = 0.35

    /// 向きが切り替わる前の見た目(撮れなかったときは nil。次の画面をフェードで出すだけにする)
    private let oldSnapshotView: UIView?
    /// 向きが切り替わる前の画面の大きさ
    private let oldSize: CGSize
    /// 横画面の向き(landscapeRight / landscapeLeft のどちらか。回す向きを決めるのに使う)
    private let landscapeOrientation: UIInterfaceOrientation

    /// - Parameters:
    ///   - oldView: 向きが切り替わる前に表示している画面(開くときは開く前の画面、閉じるときは横画面)
    ///   - landscapeOrientation: 横画面の向き(開くときは開いたあと、閉じるときは閉じる前の向き)
    init(oldView: UIView, landscapeOrientation: UIInterfaceOrientation) {
        self.oldSnapshotView = oldView.snapshotView(afterScreenUpdates: false)
        self.oldSize = oldView.bounds.size
        self.landscapeOrientation = landscapeOrientation
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return Self.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let newView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        // 消える側の画面は、スナップショットで代わりに見せるので外す(閉じるときの横画面は、縦の枠に入って形が崩れているため)
        transitionContext.view(forKey: .from)?.removeFromSuperview()

        // 背景(回している間に角に空く隙間を埋める)
        let backgroundView = UIView(frame: containerView.bounds)
        backgroundView.backgroundColor = .black
        containerView.addSubview(backgroundView)

        // 向きが切り替わる前の見た目。大きさは切り替わる前のまま、画面の中央に置く
        let snapshotView = self.oldSnapshotView
        if let snapshotView {
            snapshotView.bounds = CGRect(origin: .zero, size: self.oldSize)
            snapshotView.center = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.midY)
            containerView.addSubview(snapshotView)
        }

        // 次の画面(上に重ねて、フェードで出す)
        newView.frame = containerView.bounds
        containerView.addSubview(newView)

        // 向きが切り替わる前の向きに見せるための回転(変わらなかったときは回さない)
        let startRotation = CGAffineTransform(rotationAngle: self.rotationAngle(newSize: containerView.bounds.size))

        // 切り替わる前の向き(スナップショットだけが見える)から、今の向き(次の画面だけが見える)へ、一緒に回す
        snapshotView?.transform = startRotation
        newView.transform = startRotation
        newView.alpha = 0
        UIView.animate(withDuration: Self.duration, delay: 0, options: [.curveEaseInOut], animations: {
            snapshotView?.transform = .identity
            snapshotView?.alpha = 0
            newView.transform = .identity
            newView.alpha = 1
        }, completion: { _ in
            newView.transform = .identity
            newView.alpha = 1
            backgroundView.removeFromSuperview()
            snapshotView?.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }

    /// 向きが切り替わる前の見た目に戻すための回転の角度。向きが変わらなかったとき(iPad の画面分割中など)は 0
    ///
    ///   | 切り替わり              | 角度   |
    ///   |-------------------------|--------|
    ///   | 縦 → landscapeRight     | -90°   |
    ///   | 縦 → landscapeLeft      | +90°   |
    ///   | landscapeRight → 縦     | +90°   |
    ///   | landscapeLeft → 縦      | -90°   |
    private func rotationAngle(newSize: CGSize) -> CGFloat {
        let wasLandscape = self.oldSize.width > self.oldSize.height
        let isLandscape = newSize.width > newSize.height
        if wasLandscape == isLandscape {
            return 0
        }
        // landscapeRight の角度(landscapeLeft はその逆)
        var angle: CGFloat = -.pi / 2  // 縦 → 横
        if !isLandscape {
            angle = .pi / 2  // 横 → 縦
        }
        if self.landscapeOrientation == .landscapeLeft {
            return -angle
        }
        return angle
    }
}
