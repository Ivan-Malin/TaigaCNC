from flask import Flask, render_template, request, jsonify


id_items = ["ID1", "ID2", "ID3"]
cnc_items = ["CNC1", "CNC2", "CNC3"]

app = Flask(__name__)
class CNC_handler():
    def __init__(self, name):
        self.id_items  = []
        self.cnc_items = []
        self.link = []
        # super(Flask).__init__(name)
        # self.app = Flask(__name__)
        
    # def add_id(self,id):

    @app.route('/')
    def index():
        return render_template('index.html', id_items=id_items, cnc_items=cnc_items)

    @app.route('/update', methods=['POST'])
    def update_arrangement():
        updated_id_items = request.json['idItems']
        updated_cnc_items = request.json['cncItems']
        # Perform backend processing with the updated data

        return jsonify(success=True)

    @app.route('/get_idcnc', methods=['GET'])
    def get_idcnc():

        return jsonify(success=True)

a = CNC_handler('a')
        
    

if __name__ == '__main__':
    app.run(debug=True)
