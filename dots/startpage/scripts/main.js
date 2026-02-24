const months = [
  "January", 
  "February", 
  "March", 
  "April", 
  "May", 
  "June", 
  "July", 
  "August", 
  "September", 
  "October", 
  "November", 
  "December"
];

function getDate() {
  var dateNow = new Date();
  var month = months[dateNow.getMonth()];
  var day = dateNow.getDate();
  var year = dateNow.getFullYear();
  var hours = ('0' + dateNow.getHours()).slice(-2);
  var minutes = ('0' + dateNow.getMinutes()).slice(-2);
  var seconds = ('0' + dateNow.getSeconds()).slice(-2);
  var date = `${month} ${day}, ${year} | ${hours}:${minutes}:${seconds}`;
  document.getElementById("date").innerHTML = date;
}

document.addEventListener('DOMContentLoaded', function() {
  getDate();
  setInterval(getDate, 1000);
});

document.addEventListener("keydown", function(event) {
  if (event.key === "Escape") {
    document.activeElement.blur();
  }
});
