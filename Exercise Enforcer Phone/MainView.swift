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
            /*
            Button("Increment"){
                viewModel.incrementHeartRate()
            } */
            Spacer()
            HStack(){
                heartRateView
                Spacer()
                encouragementView
                Spacer()
                heartRateZoneView
            }
            HeartRateZoneCollectionView(activeZone: viewModel.currentHeartRateZone)
        }
        .padding()
    }
    
    var encouragementView: some View{
        if(viewModel.currentHeartRate < viewModel.TARGET_ZONE_MIN){
            Text("Go faster!")
        } else if(viewModel.currentHeartRate > viewModel.TARGET_ZONE_MAX){
            Text("Slow down!")
        }
        else{
            Text("Doing great!")
        }
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
