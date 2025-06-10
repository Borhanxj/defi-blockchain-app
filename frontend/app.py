from flask import Flask, render_template

app = Flask(__name__, static_url_path='/static')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/amm.html')
def amm_page():
    return render_template('amm.html')

@app.route('/lending')
def lending():
    return render_template('lending.html')

@app.route('/arbitraguer')
def arbitr_page():
    return render_template('arbitraguer.html')

if __name__ == '__main__':
    app.run(debug=True, port=4455)
