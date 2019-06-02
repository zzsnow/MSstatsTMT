###############################################################
## check single subject within each condition in each mixture
###############################################################
#' @keywords internal
.checkSingleSubject <- function(annotation) {

    temp <- unique(annotation[, c("Mixture", "Group", "Subject")])
    temp$Group <- factor(temp$Group)
    temp$Mixture <- factor(temp$Mixture)
    temp1 <- xtabs(~ Mixture+Group, data=temp)
    singleSubject <- all(temp1 == "1")

    return(singleSubject)
}

#############################################
## check .checkTechReplicate
#############################################
#' @keywords internal
.checkTechReplicate <-  function(annotation) {

    temp <- unique(annotation[, c("Mixture", "Run")])
    temp$Mixture <- factor(temp$Mixture)
    temp1 <- xtabs(~ Mixture, data=temp)
    TechReplicate <- all(temp1 != "1")

    return(TechReplicate)
}

#############################################
## check whether there are multiple biological mixtures
#############################################
#' @keywords internal
.checkMulBioMixture <-  function(annotation) {

    temp <- unique(annotation[, "Mixture"])
    temp <- as.vector(as.matrix(temp))

    return(length(temp)>1)
}

#############################################
## check whether there is only single run
#############################################

.checkSingleRun <-  function(annotation) {

    temp <- unique(annotation[, "Run"])
    temp <- as.vector(as.matrix(temp))

    return(length(temp)==1)
}

#############################################
## fit the full model with mixture, techrep and subject effects
#############################################
#' @import lme4
#' @keywords internal
#' fit the whole plot and subplot model if the data has 
#' multiple mixtures, multiple technical replicate runs per mixture and biological variation
fit_full_model <- function(data) {
  
  fit.mixed <- suppressMessages(try(lmer(Abundance ~ 1 + (1|Mixture) + (1|Mixture:TechRepMixture) +  # whole plot
                                           Group + #subplot
                                           (1|Subject:Group:Mixture), data = data), TRUE))
  
  fit.fixed <- suppressMessages(try(lm(Abundance ~ 1 + Mixture + Mixture:TechRepMixture +  # whole plot
                                         Group +
                                         Subject:Group:Mixture, data = data), TRUE))
  
  if((!inherits(fit.mixed, "try-error")) & (!inherits(fit.fixed, "try-error"))){
    return(list(fixed = fit.fixed, mixed = fit.mixed, subject = "Subject:Group:Mixture"))
  } else{ # if the parameters are not estimable, return null
    return(NULL)
  }
}

#############################################
## fit the reduced model with run and subject effects
#############################################
#' @import lme4
#' @keywords internal
#' fit the whole plot and subplot model if the data has 
#' single mixture with multiple technical replicate runs
fit_reduced_model_techrep <- function(data) {
  
  fit.mixed <- suppressMessages(try(lmer(Abundance ~ 1 + (1|Run) +  # whole plot
                                           Group + #subplot
                                           (1|Subject:Group), data = data), TRUE))
  
  fit.fixed <- suppressMessages(try(lm(Abundance ~ 1 + Run +  # whole plot
                                         Group +
                                         Subject:Group, data = data), TRUE))
  
  if((!inherits(fit.mixed, "try-error")) & (!inherits(fit.fixed, "try-error"))){
    return(list(fixed = fit.fixed, mixed = fit.mixed, subject = "Subject:Group"))
  } else{ # if the parameters are not estimable, return null
    return(NULL)
  }
  
}

#############################################
## fit the reduced model with mixture and techrep effects
#############################################
#' @import lme4
#' @keywords internal
#' fit the whole plot and subplot model if the data has no biological variation,
#' multiple mixtures with multiple technical replicate runs
fit_full_model_spikedin <- function(data) {
  
  fit.mixed <- suppressMessages(try(lmer(Abundance ~ 1 + (1|Mixture) + (1|Mixture:TechRepMixture) 
                                         + Group, data = data), TRUE))
  fit.fixed <- suppressMessages(try(lm(Abundance ~ 1 + Mixture + Mixture:TechRepMixture 
                                       + Group, data = data), TRUE))
  
  if((!inherits(fit.mixed, "try-error")) & (!inherits(fit.fixed, "try-error"))){
    return(list(fixed = fit.fixed, mixed = fit.mixed, subject = "None"))
  } else{ # if the parameters are not estimable, return null
    return(NULL)
  }
  
}

#############################################
## fit the reduced with only run effect
#############################################
#' @import lme4
#' @keywords internal
#' fit the whole plot and subplot model if the data has no biological variation,
#' multiple mixtures or multiple technical replicate runs
#' or if the data has multiple mixtures but single technical replicate MS run
fit_reduced_model_mulrun <- function(data) {
  
  fit.mixed <- suppressMessages(try(lmer(Abundance ~ 1 + (1|Run) + Group, data = data), TRUE))
  fit.fixed <- suppressMessages(try(lm(Abundance ~ 1 + Run + Group, data = data), TRUE))
  
  if((!inherits(fit.mixed, "try-error")) & (!inherits(fit.fixed, "try-error"))){
    return(list(fixed = fit.fixed, mixed = fit.mixed, subject = "None"))
  } else{ # if the parameters are not estimable, return null
    return(NULL)
  }
  
}

#############################################
## fit one-way anova model
#############################################
#' @import lme4
#' @keywords internal
#' fit the whole plot and subplot model if the data has single run
fit_reduced_model_onerun <- function(data) {
  
  fit <- suppressMessages(try(lm(Abundance ~ 1 + Group, data = data), TRUE))
  
  if(!inherits(fit, "try-error")){
    return(fit)
  } else{ # if the parameters are not estimable, return null
    return(NULL)
  }
  
}

#############################################
## fit the proper linear model for each protein
#############################################
#' @import lme4
#' @importFrom dplyr filter
#' @keywords internal
#' fit the proper linear model for each protein
.linear.model.fitting <- function(data){
  
  Abundance <- Group <- Protein <- NULL
  
  data$Protein <- as.character(data$Protein) ## make sure protein names are character
  proteins <- as.character(unique(data$Protein)) ## proteins
  num.protein <- length(proteins)
  linear.models <- list() # linear models
  s2.all <- NULL # sigma^2
  df.all <- NULL # degree freedom
  ## do inference for each protein individually
  for(i in 1:length(proteins)) {
    
    message(paste("Model fitting for Protein :", proteins[i] , "(", i, " of ", num.protein, ")"))
    sub_data <- data %>% dplyr::filter(Protein == proteins[i]) ## data for protein i
    sub_data <- na.omit(sub_data) 
    if(nrow(sub_data) != 0){
      ## Record the annotation information
      sub_annot <- unique(sub_data[, c('Run', 'Channel', 'Subject',
                                       'Group', 'Mixture', 'TechRepMixture')])
      
      ## check the experimental design
      sub_singleSubject <- .checkSingleSubject(sub_annot)
      sub_TechReplicate <- .checkTechReplicate(sub_annot)
      sub_bioMixture <- .checkMulBioMixture(sub_annot)
      sub_singleRun <- .checkSingleRun(sub_annot)
      
      if(sub_singleSubject){ # no biological variation within each condition and mixture
        if(sub_TechReplicate & sub_bioMixture){ # multiple mixtures and technical replicates
          # fit the full model with mixture and techrep effects for spiked-in data
          fit <- fit_full_model_spikedin(sub_data)
          
          if(is.null(fit)){ # full model is not applicable 
            # fit the reduced model with only run effect
            fit <- fit_reduced_model_mulrun(sub_data)
            
          } 
          
          if(is.null(fit)){ # the second model is not applicable
            # fit one-way anova model
            fit <- fit_reduced_model_onerun(sub_data) 
            
          }
        } else{
          if(sub_TechReplicate | sub_bioMixture){ # multiple mixtures or multiple technical replicates
            # fit the reduced model with only run effect
            fit <- fit_reduced_model_mulrun(sub_data)
            
            if(is.null(fit)){ # the second model is not applicable
              # fit one-way anova model
              fit <- fit_reduced_model_onerun(sub_data) 
              
            }
          } else{ # single run case
            # fit one-way anova model
            fit <- fit_reduced_model_onerun(sub_data) 
            
          }
        }
      } else{ # biological variation exists within each condition and mixture
        if (sub_bioMixture) {  # multiple biological mixtures
          if (sub_TechReplicate) { # multiple technical replicate MS runs
            # fit the full model with mixture, techrep, subject effects
            fit <- fit_full_model(sub_data) 
            
            if(is.null(fit)){ # full model is not applicable
              # fit the reduced model with run and subject effects
              fit <- fit_reduced_model_techrep(sub_data) 
            }
            
            if(is.null(fit)){ # second model is not applicable
              # fit one-way anova model
              fit <- fit_reduced_model_onerun(sub_data) 
            }
            
          } else { # single technical replicate MS run
            # fit the reduced model with only run effect
            fit <- fit_reduced_model_mulrun(sub_data) 
            
            if(is.null(fit)){ # second model is not applicable
              # fit one-way anova model
              fit <- fit_reduced_model_onerun(sub_data) 
            }
            
          }
        } else { # single biological mixture
          if (sub_TechReplicate) { # multiple technical replicate MS runs
            # fit the reduced model with run and subject effects
            fit <- fit_reduced_model_techrep(sub_data)
            
            if(is.null(fit)){ # second model is not applicable
              # fit one-way anova model
              fit <- fit_reduced_model_onerun(sub_data) 
            }
            
          } else { # single run
            # fit one-way anova model
            fit <- fit_reduced_model_onerun(sub_data) 
            
          } # single technical replicate MS run
        } # single biological mixture
      } # biological variation
      
      ## estimate variance and df from linear models
      if(!is.null(fit)){ # the model is fittable
        if(class(fit) == "lm"){# single run case 
          ## Estimate the group variance from fixed model
          av <- anova(fit)
          # use error variance for testing
          MSE <- av["Residuals", "Mean Sq"]
          df <- av["Residuals", "Df"]
          
        } else{ ## fit linear mixed model
          if(fit$subject=="None"){ # no technical replicates
            # Estimate the group variance and df
            varcomp <- as.data.frame(VarCorr(fit$mixed))
            # use error variance for testing
            MSE <- varcomp[varcomp$grp == "Residual", "vcov"] 
            av <- anova(fit$fixed)
            df <- av["Residuals", "Df"] # degree of freedom
            
          } else{ # multiple technical replicates
            if(fit$subject=="Subject:Group:Mixture"){ # multiple biological mixtures
              # Estimate the group variance and df
              varcomp <- as.data.frame(VarCorr(fit$mixed))
              # use subject variance for testing
              MSE <- varcomp[varcomp$grp == "Subject:Group:Mixture", "vcov"]
              av <- anova(fit$fixed)
              df <- av["Subject:Group:Mixture", "Df"] # degree of freedom
              
            } else{ # single biological mixture
              # Estimate the group variance and df
              varcomp <- as.data.frame(VarCorr(fit$mixed))
              # use subject variance for testing
              MSE <- varcomp[varcomp$grp == "Subject:Group", "vcov"]
              av <- anova(fit$fixed)
              df <- av["Subject:Group", "Df"] # degree of freedom
              
            }
          }
        }
        
        linear.models[[i]] <- fit 
        s2.all <- c(s2.all, MSE)
        df.all <- c(df.all, df)
        
      } else{ # if the model is not fittable
        linear.models[[i]] <- NA 
        s2.all <- c(s2.all, NA)
        df.all <- c(df.all, NA)
      }
      
    } else{ # if the protein data is empty
      linear.models[[i]] <- NA 
      s2.all <- c(s2.all, NA)
      df.all <- c(df.all, NA)
      
    }
  } # for each protein
  
  return(list(protein = proteins, model = linear.models, s2 = s2.all, df = df.all))
}