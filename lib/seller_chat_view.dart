Widget _buildSellerMediationUI() {
  return Column(
    children: [
      // 1. THE VIEW-ONLY CHAT STREAM
      Expanded(
        child: ListView(
          children: [
            _chatBubble(msg: "Buyer: Is the price negotiable?", isBuyer: true),
            _chatBubble(msg: "AI (Your Assistant): The price is currently firm, but I can check with the seller.", isBuyer: false),
          ],
        ),
      ),

      // 2. THE MEDIATION BOX (Where seller talks to AI)
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: const Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("INSTRUCT YOUR AI ASSISTANT", 
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "e.g., Tell him I can deliver for free...",
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // This sends the instruction TO THE AI, not the buyer
                CircleAvatar(
                  backgroundColor: Colors.black87,
                  child: IconButton(
                    icon: const Icon(Icons.bolt, color: Colors.orange, size: 20),
                    onPressed: () => _sendInstructionToAI(),
                  ),
                )
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text("Note: AI will filter contact info until fee is paid.", 
                style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    ],
  );
}