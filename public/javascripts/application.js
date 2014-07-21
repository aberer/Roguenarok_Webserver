// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults







function checkUntil(i)
{
    var nodes = document.querySelectorAll(".taxonCheck");

	<!-- alert("you got " + nodes.length + "nodes");  -->

    for(var j = 0 ; j < nodes.length ; j++)
	nodes[j].checked = 0;


    for(var j = 0; j <= i ; j++)
    { 
	document.getElementById("taxa_" + j).click() 
    }
};


function hidePruneThresholds(id1,id2){
    if (document.getElementById("tree_manipulation").value == "Ignore Selected Taxa"){
        document.getElementById(id1).style.display = "none";
        document.getElementById(id2).style.display = "none";
    }
    else if(document.getElementById("tree_manipulation").value == "Prune Taxa / Visualize"){
        document.getElementById(id1).style.display = "";
        document.getElementById(id2).style.display = "";
    }

} 

function hideAnalysisOptions(id1,id2,id3,id4){
    if (document.getElementById("taxa_analysis").value == "RogueNaRok"){
        document.getElementById(id4).style.display = "none";
        document.getElementById(id1).style.display = "";
        document.getElementById(id2).style.display = "";
        document.getElementById(id3).style.display = "";
    }
    else if (document.getElementById("taxa_analysis").value == "leaf stability index"){
        document.getElementById(id1).style.display = "none";
        document.getElementById(id2).style.display = "none";
        document.getElementById(id3).style.display = "none";
        document.getElementById(id4).style.display = "";

    }
    else if (document.getElementById("taxa_analysis").value == "taxonomic instability index"){
        document.getElementById(id1).style.display = "none";
        document.getElementById(id2).style.display = "none";
        document.getElementById(id3).style.display = "none";
        document.getElementById(id4).style.display = "none";    
    }
}
