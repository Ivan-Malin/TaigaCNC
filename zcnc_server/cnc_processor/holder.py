import tkinter as tk
import json

class DragDropManager:
    def __init__(self, root):
        self.root = root
        self.id_boxes = {}
        self.cnc_boxes = {}
        self.create_gui()

    def create_gui(self):
        self.settings_column = tk.Frame(self.root, width=200, height=600, bg="lightgrey")
        self.settings_column.grid(row=0, column=0, padx=5, pady=5)

        self.id_column = tk.Frame(self.root, width=200, height=600, bg="lightblue")
        self.id_column.grid(row=0, column=1, padx=5, pady=5)

        self.cnc_column = tk.Frame(self.root, width=200, height=600, bg="lightgreen")
        self.cnc_column.grid(row=0, column=2, padx=5, pady=5)

        # Example values
        self.create_box("ID1", self.id_column, "lightblue")
        self.create_box("ID2", self.id_column, "lightblue")
        self.create_box("ID3", self.id_column, "lightblue")

        self.create_box("CNC1", self.cnc_column, "lightgreen")
        self.create_box("CNC2", self.cnc_column, "lightgreen")
        self.create_box("CNC3", self.cnc_column, "lightgreen")

    def create_box(self, text, parent, color):
        box = tk.Label(parent, text=text, bg=color, bd=1, relief="raised")
        box.pack(pady=5)
        box.bind("<ButtonPress-1>", self.on_box_press)
        box.bind("<B1-Motion>", self.on_box_motion)
        box.bind("<ButtonRelease-1>", self.on_box_release)

        if parent == self.id_column:
            self.id_boxes[box] = text
        else:
            self.cnc_boxes[box] = text

    def on_box_press(self, event):
        widget = event.widget
        widget._drag_start_x = event.x
        widget._drag_start_y = event.y
        widget._drag_data = {"item": widget, "start_x": event.x, "start_y": event.y}

    def on_box_motion(self, event):
        widget = event.widget
        x, y = widget.winfo_pointerx() - widget.winfo_rootx(), widget.winfo_pointery() - widget.winfo_rooty()
        start_x = widget._drag_start_x
        start_y = widget._drag_start_y
        diff_x = x - start_x
        diff_y = y - start_y
        x_pos = widget.winfo_x() + diff_x
        y_pos = widget.winfo_y() + diff_y
        widget.place(x=x_pos, y=y_pos)

    def on_box_release(self, event):
        widget = event.widget
        for box, text in self.id_boxes.items():
            if box.winfo_rootx() < widget.winfo_rootx() < box.winfo_rootx() + box.winfo_width() and box.winfo_rooty() < widget.winfo_rooty() < box.winfo_rooty() + box.winfo_height():
                if widget in self.cnc_boxes:
                    cnc_text = self.cnc_boxes.pop(widget)
                    id_box = list(self.id_boxes.keys())[list(self.id_boxes.values()).index(text)]
                    self.cnc_boxes[id_box] = text
                    widget.master = self.id_column
                    widget.configure(bg="lightblue")
                    break
            elif widget in self.cnc_boxes:
                for box, text in self.cnc_boxes.items():
                    if box.winfo_rootx() < widget.winfo_rootx() < box.winfo_rootx() + box.winfo_width() and box.winfo_rooty() < widget.winfo_rooty() < box.winfo_rooty() + box.winfo_height():
                        if box in self.id_boxes:
                            id_text = self.id_boxes.pop(box)
                            self.id_boxes[widget] = text
                            widget.master = self.cnc_column
                            widget.configure(bg="lightgreen")
                            break

    def save_data(self):
        id_list = [text for box, text in self.id_boxes.items()]
        cnc_list = [text for box, text in self.cnc_boxes.items()]

        data = {'ID': id_list, 'CNC': cnc_list}

        with open('cards_info.json', 'w') as file:
            json.dump(data, file)


root = tk.Tk()
root.title("CNC Management")
app = DragDropManager(root)
save_button = tk.Button(root, text="Save", command=app.save_data)
save_button.grid(row=1, column=1, pady=10)
root.mainloop()
