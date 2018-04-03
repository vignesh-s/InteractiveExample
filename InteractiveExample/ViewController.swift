//
//  ViewController.swift
//  InteractiveExample
//
//  Created by Vignesh on 31/03/2018.
//

import Charts
import UIKit
import UIKit.UIGestureRecognizerSubclass

private enum State {
    case closed
    case open
}

extension State {
    var opposite: State {
        switch self {
        case .open: return .closed
        case .closed: return .open
        }
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var plantsReadyForWateringView: UIView!
    @IBOutlet weak var plantsReadyBottomConstraint: NSLayoutConstraint!
    @IBOutlet var plantsReadyHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var popupView: UIView!
    @IBOutlet weak var popupViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomButtonBar: UIView!
    @IBOutlet weak var wateringInfo: UIStackView!
    @IBOutlet weak var plantsInfo: UIStackView!
    @IBOutlet weak var chartView: LineChartView!
    @IBOutlet weak var daysRemainingCount: UILabel!
    @IBOutlet weak var daysText: UILabel!
    @IBOutlet weak var wateredButton: UIButton!
    
    private let popupOffset: CGFloat = -230
    private let plantsReadyPopupOffset: CGFloat = -170
    private let plantsReadyCorrectOffset: CGFloat = 130
    
    private var plantsReadyTopConstraint = NSLayoutConstraint()
    
    private var timer: Timer = Timer()
    private var remainingDays: Int = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        layout()
        panRecognizer.delegate = self
        popupView.addGestureRecognizer(panRecognizer)
        plantsReadyForWateringView.addGestureRecognizer(plantsReadyPanRecognizer)
    }
    
    private func layout() {
        
        plantsReadyBottomConstraint.constant = plantsReadyPopupOffset
        plantsReadyForWateringView.layer.cornerRadius = 15
        plantsReadyForWateringView.layer.maskedCorners =
            [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        
        plantsReadyHeightConstraint.constant = 470
        popupView.layer.cornerRadius = 15
        popupView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        popupViewBottomConstraint.constant = popupOffset
        
        plantsReadyTopConstraint = plantsReadyForWateringView.topAnchor
            .constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor)
        
        plantsReadyTopConstraint.isActive = false
        
        wateringInfo.alpha = 0
        plantsInfo.alpha = 0
        chartView.alpha = 0
        
        setChartData()
    }
    
    // MARK: - Animation
    
    /// The current state of the animation. This variable is changed only when an animation completes.
    private var currentState: State = .closed
    private var currentStateOfPlantsReady: State = .closed
    
    /// All of the currently running animators.
    private var runningAnimators = [UIViewPropertyAnimator]()
    private var runningAnimatorsForPlantsReady = [UIViewPropertyAnimator]()
    
    /// The progress of each animator. This array is parallel to the `runningAnimators` array.
    private var animationProgress = [CGFloat]()
    private var animationProgressForPlantsReady = [CGFloat]()
    
    private lazy var panRecognizer: InstantPanGestureRecognizer = {
        let recognizer = InstantPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(popupViewPanned(recognizer:)))
        return recognizer
    }()
    
    private lazy var plantsReadyPanRecognizer: InstantPanGestureRecognizer = {
        let recognizer = InstantPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(plantsReadyViewPanned(recognizer:)))
        return recognizer
    }()
    
    /// Animates the transition, if the animation is not already running.
    private func animateTransitionIfNeeded(to state: State, duration: TimeInterval) {
        
        if state == .open && self.currentStateOfPlantsReady == .open {
            self.closePlantsReadyForWatering()
        }
        // ensure that the animators array is empty (which implies new animations need to be created)
        guard runningAnimators.isEmpty else { return }
        
        // an animator for the transition
        let transitionAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1, animations: {
            switch state {
            case .open:
                self.popupViewBottomConstraint.constant = 0
                self.backgroundImage.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            case .closed:
                self.popupViewBottomConstraint.constant = self.popupOffset
                self.backgroundImage.transform = CGAffineTransform(scaleX: 1, y: 1)
            }
            self.view.layoutIfNeeded()
        })
        
        // the transition completion block
        transitionAnimator.addCompletion { position in
            
            // update the state
            switch position {
            case .start:
                self.currentState = state.opposite
            case .end:
                self.currentState = state
            case .current:
                ()
            }
            
            // manually reset the constraint positions
            switch self.currentState {
            case .open:
                self.popupViewBottomConstraint.constant = 0
            case .closed:
                self.popupViewBottomConstraint.constant = self.popupOffset
            }
            
            // remove all running animators
            self.runningAnimators.removeAll()
            
        }
        
        var curve: UIViewAnimationCurve
        if state == .open {
            curve = .easeIn
        } else {
            curve = .easeOut
        }
        let infoFadeAnimation =
            UIViewPropertyAnimator(duration: duration, curve: curve, animations: {
                
                switch state {
                case .open:
                    self.wateringInfo.alpha = 1
                    self.plantsInfo.alpha = 1
                case .closed:
                    self.wateringInfo.alpha = 0
                    self.plantsInfo.alpha = 0
                }
        })
        infoFadeAnimation.scrubsLinearly = false
        
        // start all animators
        transitionAnimator.startAnimation()
        infoFadeAnimation.startAnimation()
        
        // keep track of all running animators
        runningAnimators.append(transitionAnimator)
        runningAnimators.append(infoFadeAnimation)
        
    }
    
    private func animateTransitionIfNeededForPlantsReady(to state: State, duration: TimeInterval) {
        
        // ensure that the animators array is empty (which implies new animations need to be created)
        guard runningAnimatorsForPlantsReady.isEmpty else { return }
        
        if state == .closed {
            self.chartView.alpha = 0
        }
        
        // an animator for the transition
        let transitionAnimator =
            UIViewPropertyAnimator(duration: duration, dampingRatio: 1, animations: {
                switch state {
                case .open:
                    self.plantsReadyHeightConstraint.isActive = false
                    self.plantsReadyTopConstraint.isActive = true
                    self.plantsReadyBottomConstraint.constant = self.plantsReadyCorrectOffset
                    self.backgroundImage.transform = CGAffineTransform(scaleX: 0.9, y: 0.95)
                case .closed:
                    self.plantsReadyBottomConstraint.constant = self.plantsReadyPopupOffset
                    self.plantsReadyTopConstraint.isActive = false
                    self.plantsReadyHeightConstraint.isActive = true
                    self.backgroundImage.transform = CGAffineTransform(scaleX: 1, y: 1)
                }
                self.view.layoutIfNeeded()
        })
        
        // the transition completion block
        transitionAnimator.addCompletion { position in
            
            // update the state
            switch position {
            case .start:
                self.currentStateOfPlantsReady = state.opposite
            case .end:
                self.currentStateOfPlantsReady = state
            case .current:
                ()
            }
            
            // manually reset the constraint positions
            switch self.currentStateOfPlantsReady {
            case .open:
                self.plantsReadyHeightConstraint.isActive = false
                self.plantsReadyTopConstraint.isActive = true
                self.plantsReadyBottomConstraint.constant = self.plantsReadyCorrectOffset
                self.chartView.animate(yAxisDuration: 1)
                self.chartView.alpha = 1
            case .closed:
                self.plantsReadyBottomConstraint.constant = self.plantsReadyPopupOffset
                self.plantsReadyTopConstraint.isActive = false
                self.plantsReadyHeightConstraint.isActive = true
            }
            
            // remove all running animators
            self.runningAnimatorsForPlantsReady.removeAll()
            
        }
        // start all animators
        transitionAnimator.startAnimation()
        
        // keep track of all running animators
        runningAnimatorsForPlantsReady.append(transitionAnimator)
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            
            // start the animations
            animateTransitionIfNeeded(to: currentState.opposite, duration: 1)
            
            // pause all animations, since the next event may be a pan changed
            runningAnimators.forEach { $0.pauseAnimation() }
            
            // keep track of each animator's progress
            animationProgress = runningAnimators.map { $0.fractionComplete }
            
        case .changed:
            
            // variable setup
            let translation = recognizer.translation(in: popupView)
            var fraction = -translation.y / -popupOffset
            
            // adjust the fraction for the current state and reversed state
            if currentState == .open { fraction *= -1 }
            if runningAnimators[0].isReversed { fraction *= -1 }
            
            // apply the new fraction
            for (index, animator) in runningAnimators.enumerated() {
                animator.fractionComplete = fraction + animationProgress[index]
            }
            
        case .ended:
            
            // variable setup
            let yVelocity = recognizer.velocity(in: popupView).y
            let shouldClose = yVelocity > 0
            
            // if there is no motion, continue all animations and exit early
            if yVelocity == 0 {
                runningAnimators.forEach
                    { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
                break
            }
            
            // reverse the animations based on their current state and pan motion
            switch currentState {
            case .open:
                if !shouldClose && !runningAnimators[0].isReversed
                    { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
                if shouldClose && runningAnimators[0].isReversed
                    { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
            case .closed:
                if shouldClose && !runningAnimators[0].isReversed
                    { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
                if !shouldClose && runningAnimators[0].isReversed
                    { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
            }
            
            // continue all animations
            runningAnimators.forEach
                { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
            
        default:
            ()
        }
    }
    
    @objc private func plantsReadyViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            
            // start the animations
            animateTransitionIfNeededForPlantsReady(to: currentStateOfPlantsReady.opposite,
                                                    duration: 1)
            
            // pause all animations, since the next event may be a pan changed
            runningAnimatorsForPlantsReady.forEach { $0.pauseAnimation() }
            
            // keep track of each animator's progress
            animationProgressForPlantsReady =
                runningAnimatorsForPlantsReady.map { $0.fractionComplete }
            
        case .changed:
            
            // variable setup
            let translation = recognizer.translation(in: plantsReadyForWateringView)
            var fraction = -translation.y / -plantsReadyPopupOffset
            
            // adjust the fraction for the current state and reversed state
            if currentStateOfPlantsReady == .open { fraction *= -1 }
            if runningAnimatorsForPlantsReady[0].isReversed { fraction *= -1 }
            
            // apply the new fraction
            for (index, animator) in runningAnimatorsForPlantsReady.enumerated() {
                animator.fractionComplete = fraction + animationProgressForPlantsReady[index]
            }
            
        case .ended:
            
            // variable setup
            let yVelocity = recognizer.velocity(in: plantsReadyForWateringView).y
            let shouldClose = yVelocity > 0
            
            // if there is no motion, continue all animations and exit early
            if yVelocity == 0 {
                runningAnimatorsForPlantsReady.forEach
                    { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
                break
            }
            
            // reverse the animations based on their current state and pan motion
            switch currentStateOfPlantsReady {
            case .open:
                if !shouldClose && !runningAnimatorsForPlantsReady[0].isReversed
                    { runningAnimatorsForPlantsReady.forEach { $0.isReversed = !$0.isReversed } }
                if shouldClose && runningAnimatorsForPlantsReady[0].isReversed
                    { runningAnimatorsForPlantsReady.forEach { $0.isReversed = !$0.isReversed } }
            case .closed:
                if shouldClose && !runningAnimatorsForPlantsReady[0].isReversed
                    { runningAnimatorsForPlantsReady.forEach { $0.isReversed = !$0.isReversed } }
                if !shouldClose && runningAnimatorsForPlantsReady[0].isReversed
                    { runningAnimatorsForPlantsReady.forEach { $0.isReversed = !$0.isReversed } }
            }
            
            // continue all animations
            runningAnimatorsForPlantsReady.forEach
                { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
            
        default:
            ()
        }
    }
    
    func closePlantsReadyForWatering() {
        animateTransitionIfNeededForPlantsReady(to: currentStateOfPlantsReady.opposite, duration: 2)
    }
    
    @IBAction func onClickWateredButton(_ sender: UIButton) {
        wateredButton.isEnabled = false
        if currentState == .open {
            animateTransitionIfNeeded(to: currentState.opposite, duration: 1)
        }
        timer = Timer.scheduledTimer(timeInterval: 0.10, target: self, selector:
            #selector(self.increaseRemainingDays), userInfo: nil, repeats: true)
        
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
    }
    
    @objc func increaseRemainingDays() {
        remainingDays += 1
        daysRemainingCount.text = "\(remainingDays)"
        daysText.text = "days"
        if remainingDays == 7 {
            timer.invalidate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.startNextWateringDaysTimer()
            }
        }
    }
    
    func startNextWateringDaysTimer() {
        timer = Timer.scheduledTimer(timeInterval: 0.20, target: self, selector:
            #selector(self.decreaseRemainingDays), userInfo: nil, repeats: true)
        
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
    }
    
    @objc func decreaseRemainingDays() {
        remainingDays -= 1
        daysRemainingCount.text = "\(remainingDays)"
        if remainingDays == 1 {
            daysText.text = "day"
            timer.invalidate()
            wateredButton.isEnabled = true
        }
    }
    
    func setChartData() {
        
        let values = [
            ChartDataEntry(x: 1, y: 5),
            ChartDataEntry(x: 2, y: 2),
            ChartDataEntry(x: 3, y: 8),
            ChartDataEntry(x: 4, y: 10),
            ChartDataEntry(x: 5, y: 15),
            ChartDataEntry(x: 6, y: 5),
            ChartDataEntry(x: 7, y: 1)
        ]
        
        let dataSet = LineChartDataSet(values: values, label: "")
        dataSet.drawIconsEnabled = false
        dataSet.setColor(.white)
        dataSet.lineWidth = 1
        dataSet.circleRadius = 0
        dataSet.drawValuesEnabled = false
        
        let gradientColors = [ChartColorTemplates.colorFromString("#0000ccaa").cgColor,
                              ChartColorTemplates.colorFromString("#00ccaa").cgColor]
        
        let gradient = CGGradient(colorsSpace: nil,
                                  colors: gradientColors as CFArray, locations: nil)!
        
        dataSet.fillAlpha = 1
        dataSet.fill = Fill(linearGradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        
        let llXAxis = ChartLimitLine(limit: 4, label: "")
        llXAxis.lineWidth = 3
        llXAxis.lineColor = .darkGray
        
        let xAxis = chartView.xAxis
        xAxis.labelFont = .boldSystemFont(ofSize: 11)
        xAxis.labelTextColor = .white
        xAxis.labelPosition = .bottom
        xAxis.axisMinimum = 1
        xAxis.axisMaximum = 7
        xAxis.valueFormatter = GraphAxisLabelFormatter()
        xAxis.drawGridLinesEnabled = false
        xAxis.addLimitLine(llXAxis)
        
        let leftAxis = chartView.leftAxis
        leftAxis.labelFont = .boldSystemFont(ofSize: 11)
        leftAxis.labelTextColor = .white
        leftAxis.granularity = 5
        leftAxis.axisMaximum = 20
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawAxisLineEnabled = false
        
        let rightAxis = chartView.rightAxis
        rightAxis.drawGridLinesEnabled = false
        rightAxis.drawAxisLineEnabled = false
        
        let data = LineChartData(dataSet: dataSet)
        
        chartView.data = data
        chartView.chartDescription?.enabled = false
        chartView.dragEnabled = false
        chartView.setScaleEnabled(false)
        chartView.pinchZoomEnabled = false
        chartView.legend.enabled = false
        
        DispatchQueue.main.async {
            self.chartView.setNeedsDisplay()
            self.viewDidLayoutSubviews()
        }
    }
    
}

extension ViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        
        return touch.view == nil || !touch.view!.isDescendant(of: wateredButton)
    }
}

// MARK: - InstantPanGestureRecognizer

/// A pan gesture that enters into the `began` state on touch down instead of waiting for a touches moved event.
class InstantPanGestureRecognizer: UIPanGestureRecognizer {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if (self.state == UIGestureRecognizerState.began) { return }
        super.touchesBegan(touches, with: event)
        self.state = UIGestureRecognizerState.began
    }
    
}

