let IDs  = new Array();
let CNCs = new Array();
// let link = {};

function getInitValues() {
    IDs = Array.from(document.getElementById("id-column").children).map(item => item.textContent);
    CNCs = Array.from(document.getElementById("cnc-column").children).map(item => item.textContent);
}

getInitValues();

function saveArrangement() {
    let link = {};
    Array.prototype.forEach.call(document.getElementById("id-column").children, IDel => {
        Array.prototype.forEach.call(IDel.children, CNCel => {
            link[IDs.indexOf(IDel.textContent)] = CNCs.indexOf(CNCel.textContent);
        })
    });
    console.log(link);

    fetch('/update', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ idItems: idItems, cncItems: cncItems })
    })
    .then(response => response.json())
    .then(data => {
        // console.log('Updated arrangement saved successfully');

    });
}

function allowDrop(event) {
    event.preventDefault();
}

function insertAfter(existingNode, newNode) {
    existingNode.parentNode.insertBefore(newNode, existingNode.nextSibling);
}

function drop(event) {
    event.preventDefault();
    var data = event.dataTransfer.getData("text/plain");
    var target = event.target;

    // if (target.className === "box") {
    //     target.parentElement.appendChild(document.getElementById(data));
    // } else {
    //     while (target.className !== "column") {
    //         target = target.parentElement;
    //     }
    //     target.appendChild(document.getElementById(data));
    // }
    const Nmax = 10;
    let N=0;
    let currentRealTarget = NaN;
    while (target.className !== "ID-box") {
        currentRealTarget = target;
        target = target.parentElement;
        N++;
        if (N>Nmax) {
            break;
        }
    }
    if (target.children.length==0) {
        if (N<=Nmax) {
            // target.appendChild(document.getElementById(data));
            // insertAfter(currentRealTarget, document.getElementById(data));
            if (isNaN(currentRealTarget)) {
                target.appendChild(document.getElementById(data));
            }
            else {
                insertAfter(currentRealTarget, document.getElementById(data));
            }

            document.getElementById(data).style.position = "static";
            document.getElementById(data).style.marginTop = "10px";

            saveArrangement(); // Save the updated arrangement
        }
    }
}

function dropBack(event) {
    event.preventDefault();
    var data = event.dataTransfer.getData("text/plain");
    var target = event.target;
    let currentRealTarget = NaN;
    while (target.className !== "column") {
        currentRealTarget = target;
        target = target.parentElement;
    }

    // if (target.className === "box") {
    //     target.parentElement.appendChild(document.getElementById(data));
    // } else {
    //     while (target.className !== "column") {
    //         target = target.parentElement;
    //     }
    //     target.appendChild(document.getElementById(data));
    // }
    // if ('1' in 'b')
    // {

    // }
    console.log('1');
    console.log(data);
    console.log(document.getElementById(data));
    if (isNaN(currentRealTarget)){
        target.appendChild(document.getElementById(data));
    }
    else {
        insertAfter(currentRealTarget, document.getElementById(data));
    }
    document.getElementById(data).style.position = "static";
    document.getElementById(data).style.marginTop = "5px";

    saveArrangement(); // Save the updated arrangement
}
