import SwiftUI

struct GameState {
    var player1Hunger: Int = 100
    var player2Hunger: Int = 100
    var currentPlayer: Int = 1
    var turnNumber: Int = 1
    var gameOver: Bool = false
    var winner: String = ""
    var gameMessage: String = "Player 1's Turn"
    
    mutating func nextTurn() {
        guard !gameOver else { return }
        
        // Decrease hunger for current player
        if currentPlayer == 1 {
            player1Hunger = max(0, player1Hunger - 15)
        } else {
            player2Hunger = max(0, player2Hunger - 15)
        }
        
        // Check for game over
        if player1Hunger <= 0 || player2Hunger <= 0 || turnNumber >= 20 {
            gameOver = true
            if player1Hunger <= 0 && player2Hunger <= 0 {
                winner = "Draw!"
            } else if player1Hunger <= 0 {
                winner = "Player 2 Wins!"
            } else if player2Hunger <= 0 {
                winner = "Player 1 Wins!"
            } else {
                winner = player1Hunger > player2Hunger ? "Player 1 Wins!" : player2Hunger > player1Hunger ? "Player 2 Wins!" : "Draw!"
            }
            gameMessage = winner
            return
        }
        
        // Switch players
        currentPlayer = currentPlayer == 1 ? 2 : 1
        turnNumber += 1
        gameMessage = "Player \(currentPlayer)'s Turn"
    }
    
    mutating func reset() {
        self = GameState()
    }
}

enum Action: CaseIterable {
    case searchSolo, rest, shareFood
    
    var title: String {
        switch self {
        case .searchSolo: return "Search Solo"
        case .rest: return "Rest"  
        case .shareFood: return "Share Food"
        }
    }
}

struct StarvationGameView: View {
    @State private var gameState = GameState()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Game Status
                VStack {
                    Text("Turn \(gameState.turnNumber)/20")
                        .font(.headline)
                    Text(gameState.gameMessage)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(gameState.gameOver ? .red : .primary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Player Stats
                HStack {
                    PlayerView(player: 1, hunger: gameState.player1Hunger, isActive: gameState.currentPlayer == 1 && !gameState.gameOver)
                    PlayerView(player: 2, hunger: gameState.player2Hunger, isActive: gameState.currentPlayer == 2 && !gameState.gameOver)
                }
                
                Spacer()
                
                // Actions
                if !gameState.gameOver {
                    VStack(spacing: 15) {
                        ActionButton(title: "Search Solo", subtitle: "60% chance +30 food") {
                            performAction(.searchSolo)
                        }
                        ActionButton(title: "Rest", subtitle: "Restore 20 energy") {
                            performAction(.rest)
                        }
                        ActionButton(title: "Share Food", subtitle: "Give 20 to other player") {
                            performAction(.shareFood)
                        }
                    }
                } else {
                    if #available(iOS 16.0, *) {
                        Button("Restart Game") {
                            gameState.reset()
                        }
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    } else {
                        // Fallback on earlier versions
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Starvation Game")
        }
    }
    
    private func performAction(_ action: Action) {
        switch action {
        case .searchSolo:
            if Int.random(in: 1...100) <= 60 {
                if gameState.currentPlayer == 1 {
                    gameState.player1Hunger = min(100, gameState.player1Hunger + 30)
                } else {
                    gameState.player2Hunger = min(100, gameState.player2Hunger + 30)
                }
                gameState.gameMessage = "Player \(gameState.currentPlayer) found food!"
            } else {
                gameState.gameMessage = "Player \(gameState.currentPlayer) found nothing"
            }
            
        case .rest:
            gameState.gameMessage = "Player \(gameState.currentPlayer) rested"
            if gameState.currentPlayer == 1 {
                gameState.player1Hunger = min(100, gameState.player1Hunger + 20)
            } else {
                gameState.player2Hunger = min(100, gameState.player2Hunger + 20)
            }
            gameState.gameMessage = "Player \(gameState.currentPlayer) rested and restored 20 energy"
        case .shareFood:
            if gameState.currentPlayer == 1 {
                gameState.player2Hunger = min(100, gameState.player2Hunger + 20)
            } else {
                gameState.player1Hunger = min(100, gameState.player1Hunger + 20)
            }
            gameState.gameMessage = "Player \(gameState.currentPlayer) shared food"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            gameState.nextTurn()
        }
    }
}

struct PlayerView: View {
    let player: Int
    let hunger: Int
    let isActive: Bool
    
    var body: some View {
        VStack {
            Text("Player \(player)")
                .font(.headline)
            Text("Hunger: \(hunger)")
                .font(.subheadline)
                .foregroundColor(hunger > 30 ? .green : .red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(isActive ? Color.blue.opacity(0.2) : Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ActionButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
        }
    }
}

#if DEBUG
struct StarvationGameView_Previews: PreviewProvider {
    static var previews: some View {
        StarvationGameView()
    }
}
#endif
