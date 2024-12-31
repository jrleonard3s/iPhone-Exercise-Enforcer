//
//  MainView.swift
//  Exercise Enforcer Phone
//
//  Created by Joshua Leonard on 12/10/24.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: ExerciseEnforcer
    var body: some View {
        VStack {
            Spacer()
            encouragementView
            Spacer()
            HStack(){
                heartRateView
                Spacer()
                timerView
                Spacer()
                heartRateZoneView
            }
            HeartRateZoneCollectionView(activeZone: viewModel.currentHeartRateZone)
            mediaView
            if(viewModel.enableDebug){
                debugView
            }
            Spacer()
        }
        .padding()
    }
    
    var timerView: some View{
        VStack(){Text(viewModel.timeRemainingString).font(.system(size: 50)).padding(1)
            ZStack(){
                Button("Start"){
                    viewModel.startWorkout()
                }.font(.title).disabled(!viewModel.workoutPaused).opacity(!viewModel.workoutPaused ? 0 : 1)
                Button("Pause"){
                    viewModel.pauseWorkout()
                }.font(.title).disabled(viewModel.workoutPaused).opacity(viewModel.workoutPaused ? 0 : 1)
            }.buttonStyle(.bordered).padding(.top, 1).padding(.bottom, 30)
        }.lineSpacing(0.0)
    }
    
    var encouragementView: some View{
        ZStack(){
            let heartrateInTargetZone = viewModel.currentHeartRate >= viewModel.TARGET_ZONE_MIN && viewModel.currentHeartRate <= viewModel.TARGET_ZONE_MAX
            RoundedRectangle(cornerRadius: 1.0).fill(heartrateInTargetZone ? .green : .red).frame(maxWidth: .infinity).aspectRatio(5.0, contentMode: .fit)
            if(viewModel.currentHeartRate < viewModel.TARGET_ZONE_MIN){
                Text("Go faster!")
            } else if(viewModel.currentHeartRate > viewModel.TARGET_ZONE_MAX){
                Text("Slow down!")
            }
            else{
                Text("Doing great!")
            }
        }.font(.largeTitle).bold()
    }
    
    var heartRateView: some View{
        VStack(){
            Text(String(viewModel.currentHeartRate))
                .font(.largeTitle).padding(5).padding([.bottom], 0)
            Text("BPM").padding([.horizontal,.bottom], 5).padding([.top], 0)
        }.border(.black)
    }
    var heartRateZoneView: some View{
        VStack(){
            Text(String(viewModel.currentHeartRateZone))
                .font(.largeTitle).padding(5).padding([.bottom], 0)
            Text("Zone").padding([.horizontal,.bottom], 5).padding([.top], 0)
        }.border(.black)
    }
    var mediaView: some View{
        VStack(){
            Text(viewModel.mediaPaused ? "Media interrupted" : "Media playing").font(.largeTitle)
            if(viewModel.mediaPaused && viewModel.timeUntilPlaySeconds <= 3 && viewModel.timeUntilPlaySeconds > 0){
                Text("playing in \(viewModel.timeUntilPlaySeconds)")
            }
            else if(!viewModel.mediaPaused && viewModel.timeUntilPauseSeconds <= 5 && viewModel.timeUntilPauseSeconds > 0)
            {
                Text("pausing in \(viewModel.timeUntilPauseSeconds)")
            }
        }
    }
    var debugView: some View{
        HStack(){
            Button("lowBPM"){
                viewModel.setDebugBPM(70)
            }
            Button("inZoneBPM"){
                viewModel.setDebugBPM(140)
            }
            Button("highBPM"){
                viewModel.setDebugBPM(240)
            }
        }
    }
    
}


struct HeartRateZoneCollectionView: View {
    var activeZone: UInt = 0
    var body: some View {
        HStack() {
            Text("<<").opacity(activeZone == 0 ? 1 : 0).fontWeight(.bold)
            HStack(spacing:0){
                HeartRateView(zoneNumber: 1, zoneColor: .gray, activeZone: activeZone)
                HeartRateView(zoneNumber: 2, zoneColor: .blue, activeZone: activeZone)
                HeartRateView(zoneNumber: 3, zoneColor: .green, activeZone: activeZone)
                HeartRateView(zoneNumber: 4, zoneColor: .orange, activeZone: activeZone)
                HeartRateView(zoneNumber: 5, zoneColor: .red, activeZone: activeZone)}.border(Color.black, width: 0.5)
            Text(">>").opacity(activeZone == 6 ? 1 : 0).fontWeight(.bold)
        }
    }
}

struct HeartRateView: View {
    let zoneNumber: UInt
    let zoneColor: Color
    let activeZone: UInt
    var body: some View {
        ZStack {
            Rectangle().aspectRatio(1, contentMode: .fit).foregroundStyle(zoneColor)
            Text(String(zoneNumber)).bold(zoneNumber == activeZone)
        }.opacity(zoneNumber == activeZone ? 1 : 0.2)
    }
}




#Preview {
    MainView(viewModel: ExerciseEnforcer())
}
