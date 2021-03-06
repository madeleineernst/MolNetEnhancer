#' Mass2Motif_2_Network
#'
#' @param edges edges file from GNPS
#' @param motifs motif summary table from MS2LDA
#' @param prob minimal probability score for a Mass2Motif to be included. Default is 0.01. 
#' @param overlap minimal overlap score for a Mass2Motif to be included. Default is 0.3.
#' @param top parameter specifiying how many most shared motifs per molecular family (network component index) should be shown. Default is 5.
#'
#' @return edges and nodes file with Mass2Motifs mapped
#' @export
#'
#' @examples
#' @import stats 
#' @import plyr 

Mass2Motif_2_Network <- function(edges,motifs,prob = 0.01,overlap = 0.3, top = 5){
  
  if (colnames(motifs)[1] != "scans"){
    print("WARNING: First column is used for ID matching")
    colnames(motifs)[1] <- "scans"
  }
   
  # set cutoff for motifs to be included: Probability min. 0.01 and Overlap min 0.3 is default
  motifs <- motifs[intersect(which(motifs$probability >= prob), which(motifs$overlap >= overlap)),]
  
  # create additional column in edges file containing shared motifs between each node pair
  shared_motifs <- function(nodes){
    a <- motifs$motif[motifs$scans %in% nodes[1]]
    b <- motifs$motif[motifs$scans %in% nodes[2]]
    out <- paste(sort(intersect(a,b)),collapse = ",")
    return(out)
  }
  
  edges$SharedMotifs <- apply(edges[,c(1:2)], 1, shared_motifs)
  edges$interaction <- "cosine"
  
  # add additional rows for each shared motif, so each shared motif can be displayed with an individual edge
  l <- strsplit(edges$SharedMotifs,split=",")
  
  edges_m <- edges[rep(seq_len(dim(edges)[1]), lengths(l)), ]
  edges_m$interaction <- unlist(l)
  edges <- rbind(edges, edges_m)
  
  # add additional column in edges file containing the x most shared motifs per molecular family
  agg <- stats::aggregate(interaction~ComponentIndex, data = edges_m[-which(edges_m$ComponentIndex == -1),], paste0, collapse=",")
  
  agg_c <- strsplit(as.character(agg$interaction),split = ",")
  c <- lapply(agg_c,plyr::count)
  topX <- lapply(c, function(x) x[order(x$freq,decreasing=T), ])
  topX <- lapply(topX, function(x) x[1:top,1])
  topX <- unlist(lapply(topX, paste0, collapse = ","))
  agg$topX <- topX
  
  edges$topX <- agg$topX[match(edges$ComponentIndex,agg$ComponentIndex)]
  
  # reorder columns
  edges <- edges[,c("CLUSTERID1", "interaction", "CLUSTERID2", "DeltaMZ", "MEH", "Cosine", 
                                  "OtherScore", "ComponentIndex", "SharedMotifs", "topX")]
  
  edges <- edges[order(edges$ComponentIndex),]
  
  # create node table containing overlap scores of motifs per node
  motifs[-1] = apply(motifs[-1],2,as.character)
  motifs_cytoscape <- stats::aggregate(motifs[-1],by=list(motifs$scans),c)
  
  ul <- function(lcol){
    if(is.list(lcol)==TRUE){
      ulcol <- unlist(lapply(lcol,paste,collapse=","))
    }
    return(ulcol)
  }
  
  motifs_cytoscape <- as.data.frame(apply(motifs_cytoscape,2,ul),stringsAsFactors = F)
  
  splitmot <- unique(unlist(strsplit(motifs_cytoscape$motif, ",")))
  
  mat <- matrix("0.00",nrow(motifs_cytoscape),length(splitmot))
  colnames(mat) <- splitmot
  
  for (i in 1:nrow(motifs_cytoscape)){
    w <- match(unlist(strsplit(motifs_cytoscape$motif[i],",")), colnames(mat))
    mat[i,w] <- unlist(strsplit(motifs_cytoscape$overlap[i],","))
  }
  
  mat <- cbind(motifs_cytoscape,mat)
  colnames(mat)[1] <- "scans"
  
  return(list(edges = edges, nodes = mat))
}

#' make_classyfire_graphml
#'
#' @param graphML network file from GNPS (graphML)
#' @param final dataframe containing most predominant chemical classes per node at each level of the ClassyFire chemical ontology
#'
#' @return network file with most predominant chemical classes per node mapped at each level of the ClassyFire chemical ontology (graphML)
#' @export
#'
#' @examples
#' @import igraph 

make_classyfire_graphml <- function(graphML,final){
    
    finalordered <- final[match(vertex_attr(graphML,'id'),final$`cluster index`),]
    
    for (i in 1:ncol(final)){
        att <- colnames(finalordered)[i]
        vertex_attr(graphML,att) <- finalordered[,i]
    }
    
    return(graphML)
}


#' make_motif_graphml
#'
#' @param nodes A dataframe showing Mass2Motifs per node
#' @param edges A dataframe showing shared Mass2Motifs for each network pair
#'
#' @return A network file with Mass2Motifs mapped on nodes and shared Mass2Motifs mapped as multiple edges (graphML)
#' @export
#'
#' @examples
#' @import igraph 

make_motif_graphml <- function(nodes,edges){
    
    n1 <- which(colnames(edges) == 'CLUSTERID1')
    n2 <- which(colnames(edges) == 'CLUSTERID2')
    
    edges[,n1] <- as.character(edges[,n1])
    edges[,n2] <- as.character(edges[,n2])
    
    miss <- unique(c(edges$CLUSTERID1,edges$CLUSTERID2))[-which(unique(c(edges$CLUSTERID1,edges$CLUSTERID2)) %in% nodes$scans)]
    n <- matrix("",length(miss),ncol(nodes))
    n[,1] <- miss
    n <- as.data.frame(n, stringsAsFactors = F)
    colnames(n) <- colnames(nodes)
    allnodes <- rbind(nodes, n)
    
    wmotifs <- grep('motif_',colnames(allnodes))
    
    for (i in 1:length(wmotifs)){
        allnodes[,wmotifs[i]] <- as.numeric(as.character(allnodes[,wmotifs[i]]))
    }
    
    edat <- which(colnames(edges) %in% (colnames(edges)[-which(colnames(edges) %in% c('CLUSTERID1','CLUSTERID2'))]))
    
    g <- graph_from_data_frame(edges[,c(n1,n2,2,4:10)], directed=FALSE, allnodes)
    names(vertex_attr(g))[which(names(vertex_attr(g)) == 'name')] <- 'id'
    
    return(g)
    
}