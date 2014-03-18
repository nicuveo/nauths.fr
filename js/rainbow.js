/*
 * rainbow.js
 * Adds a running rainbow dash to the website. Ain't that cool?
*/


var intervals = new Array();

var UpdateRainbowDashPosition = function(rainbowDash) {
    rainbowDash.style.left = rainbowDash.position + "px";
}

var MoveRainbowDash = function(dash) {
    var ponyContainer = document.getElementById("pony");

    if (dash.position > window.innerWidth) {
        ponyContainer.removeChild(dash);
        clearInterval(intervals.shift());
        if (intervals.length == 0) {
            ponyContainer.style.display = "none";
        }
    } else {
        dash.position += 10;
        UpdateRainbowDashPosition(dash);
    }
}

var Rainbow = function() {
    var ponyContainer = document.getElementById("pony");
    var dash = document.createElement("img");

    dash.position = -200;
    dash.setAttribute("src", "/img/rainbow_dash.gif");
    dash.setAttribute("width", "200px");
    dash.style.position = "absolute";
    dash.style.top = "0";
    UpdateRainbowDashPosition(dash);
    ponyContainer.appendChild(dash);
    ponyContainer.style.display = "block";

    intervals.push(setInterval(function() { MoveRainbowDash(dash) }, 20));
}



var RainbowDashSpawn = new Konami(Rainbow);
