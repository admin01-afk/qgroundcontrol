import tkinter as tk
import threading
import time

class ServerGUI:
    def __init__(self, competition):
        self.competition = competition
        self.root = tk.Tk()
        self.root.title("Competition Server")
        
        self.toggle_btn = tk.Button(
            self.root,
            text="Toggle Fake Planes",
            command=self.toggle_fake_planes
        )

        self.label = tk.Label(
            self.root,
            text="",
            font=("Consolas", 10),
            justify="left"
        )
        self.label.pack(padx=10, pady=10)

        self.toggle_btn.pack(pady=5)

        self.update_loop()

    def toggle_fake_planes(self):
        self.competition.toggle_mode()

    def update_loop(self):
        planes = self.competition.last_state.get("konum_bilgileri", [])

        info = f"Mode: {self.competition.mode.upper()}\n"
        info += f"Aircraft: {len(planes)}\n\n"

        for p in planes:
            info += (
                f"Team {p['takim_numarasi']} | "
                f"Lat: {p['iha_enlem']:.6f} | "
                f"Lon: {p['iha_boylam']:.6f}\n"
            )

        self.label.config(text=info)
        self.root.after(500, self.update_loop)


    def run(self):
        self.root.mainloop()
