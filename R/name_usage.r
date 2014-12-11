#' Lookup details for specific names in all taxonomies in GBIF.
#'
#' @export
#' @template occ
#' @template nameusage
#' @return A list of length two. The first element is metadata. The second is 
#' a data.frame
#' @references \url{http://www.gbif.org/developer/species#nameUsages}
#' @details
#' This service uses fuzzy lookup so that you can put in partial names and 
#' you should get back those things that match. See examples below.
#' 
#' This function is different from \code{name_lookup} in that that function 
#' searches for names. This function encompasses a bunch of API endpoints, 
#' most of which require that you already have a taxon key, but there is one 
#' endpoint that allows name searches (see examples below).
#' 
#' Note that \code{data="verbatim"} hasn't been working.
#' 
#' Options for the data parameter are: 'all', 'verbatim', 'name', 'parents', 'children', 
#' 'related', 'synonyms', 'descriptions','distributions', 'images', 
#' 'references', 'speciesProfiles', 'vernacularNames', 'typeSpecimens', 'root'
#' 
#' This function used to be vectorized with respect to the \code{data} parameter, 
#' where you could pass in multiple values and the function internally loops
#' over each option making separate requests. This has been removed. You can still 
#' loop over many options for the \code{data} parameter, just use an \code{lapply}
#' family function, or a for loop, etc. 
#' @examples \dontrun{
#' # All name usages
#' name_usage()
#' 
#' # A single name usage
#' name_usage(key=1)
#' 
#' # Name usage for a taxonomic name
#' name_usage(name='Puma concolor')
#' name_usage(name='Puma', rank="GENUS")
#' 
#' # References for a name usage
#' name_usage(key=3119195, data='references')
#' 
#' # Species profiles, descriptions
#' name_usage(key=3119195, data='speciesProfiles')
#' name_usage(key=3119195, data='descriptions')
#' name_usage(key=2435099, data='children')
#' res$data$scientificName
#' 
#' # Vernacular names for a name usage
#' name_usage(key=3119195, data='vernacularNames')
#' 
#' # Limit number of results returned
#' name_usage(key=3119195, data='vernacularNames', limit=3)
#' 
#' # Search for names by dataset with datasetKey parameter
#' name_usage(datasetKey="d7dddbf4-2cf0-4f39-9b2a-bb099caae36c")
#' 
#' # Search for a particular language
#' name_usage(key=3119195, language="FRENCH", data='vernacularNames')
#' 
#' # Pass on httr options
#' ## here, print progress, notice the progress bar
#' library('httr')
#' res <- name_usage(name='Puma concolor', limit=300, config=progress())
#' }
#' 
#' @examples \donttest{
#' ### Not working right now for some unknown reason
#' # Select many options
#' name_usage(key=3119195, data=c('images','synonyms'))
#' }

name_usage <- function(key=NULL, name=NULL, data='all', language=NULL, datasetKey=NULL, uuid=NULL,
  sourceId=NULL, rank=NULL, shortname=NULL, start=NULL, limit=100, return='all', ...)
{
  calls <- names(sapply(match.call(), deparse))[-1]
  calls_vec <- c("sourceId") %in% calls
  if(any(calls_vec))
    stop("Parameters not currently accepted: \n sourceId")
   
  args <- rgbif_compact(list(language=language, name=name, datasetKey=datasetKey, 
                       rank=rank, offset=start, limit=limit, sourceId=sourceId))
  data <- match.arg(data, 
      choices=c('all', 'verbatim', 'name', 'parents', 'children',
                'related', 'synonyms', 'descriptions',
                'distributions', 'images', 'references', 'speciesProfiles',
                'vernacularNames', 'typeSpecimens', 'root'), several.ok=TRUE)
  # if(length(data)==1) getdata(data) else lapply(data, getdata)
  out <- getdata(data, key, uuid, shortname, ...)
  # select output
  return <- match.arg(return, c('meta','data','all'))
  switch(return,
         meta = data.frame(get_meta(out), stringsAsFactors=FALSE),
         data = name_usage_parse(out, data),
         all = list(meta=data.frame(get_meta(out), stringsAsFactors=FALSE), 
                    data=name_usage_parse(out, data))
  )
}

get_meta <- function(x){
  if(has_meta(x)) x[c('offset','limit','endOfRecords')] else NA
}

has_meta <- function(x) any(c('offset','limit','endOfRecords') %in% names(x))

getdata <- function(x, key, uuid, shortname, ...){
  if(!x == 'all' && is.null(key))
    stop('You must specify a key if data does not equal "all"')
  
  if(x == 'all' && is.null(key)){
    url <- paste0(gbif_base(), '/species')
  } else
  {
    if(x=='all' && !is.null(key)){
      url <- sprintf('%s/species/%s', gbif_base(), key)
    } else
      if(x %in% c('verbatim', 'name', 'parents', 'children', 
                  'related', 'synonyms', 'descriptions',
                  'distributions', 'images', 'references', 'speciesProfiles',
                  'vernacularNames', 'typeSpecimens')){
        url <- sprintf('%s/species/%s/%s', gbif_base(), key, x)
      } else
        if(x == 'root'){
          url <- sprintf('%s/species/root/%s/%s', gbif_base(), uuid, shortname)
        }
  }
  gbif_GET(url, args, FALSE, ...)
}

name_usage_parse <- function(x, y){
  if(has_meta(x)){
    do.call(rbind.fill, lapply(x$results, nameusageparser, data=y))
  } else {
    nameusageparser(x, data=y)
  }
}

nameusageparser <- function(z, data){
  tomove <- c('key','scientificName')
  tmp <- lapply(z, function(y) if(length(y) == 0) NA else y)
  df <- data.frame(tmp, stringsAsFactors=FALSE)
  if( all(tomove %in% names(df)) ) movecols(df, tomove) else df
  # if(data=="all") movecols(df, c('key','scientificName')) else df
}
