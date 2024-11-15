model gestion

global {
    file shape_file_maison <- file("../includes/building_polygon.shp");
    file shape_file_route <- file("../includes/highway_line.shp");
    file shape_file_centre_traitement <- file("../includes/Depot_ordure.shp");
    file shape_file_poubelle <- file("../includes/bac_ordure.shp");
    image_file icon <- image_file("../includes/personne.png");
    image_file camions <- image_file("../includes/camion.png");
    image_file poubelles <- image_file("../includes/poubelle.png");
    bool poubelle_remplis <- false;
    string etat <- "vide";
    list<point> points_trouver;
    string buut;
    bool alert_poubelle_vide;
    int nombre_poubelles_pleines <- 0;
    int nombre_poubelles;
    int nombre_poubelles_en_cours_remplissage <- 0;
    int nombre_camions_a_destination <- 0;
    int nombre_camion <- 10 parameter: 'Nombre' category: 'Nombre de camions' min: 0 max: 500; // Valeur initiale des camions
    int nombre_personnes <- 100 parameter: 'Nombre' category: 'Nombre de personnes' min: 0 max: 500; // Valeur initiale des personnes
    string etat_poubelle;
    string poubelle_vide;
    string poubelle_mis_pleine;
    string poubelle_pleine;
    int count_mis_pleine;
    int count_pleine;
    list<point> centre <- [{521.8032714891774, 450.196165803917, 0.0}, {1950.1656027832004, 1550.6502951083576, 0.0}];
    int count_attack_tree;
    int capacite_poubelle <- 50;
    bool poubelle_occupe <- false;
    geometry shape <- envelope(shape_file_route);
    graph road_network;
    int compte_dechet <- 0;
	bool poubelle_remplie <- false;
    int jour_courant <- 0;
    float total_ordures_ramassees <- 0.0;
    float temps_total_deplacement <- 0.0;
    float temps_total_dechargement <- 0.0;
    float distance_totale_parcourue <- 0.0;
    int nombre_trajets <- 0;
    int nombre_poubelles_vides <- 0;

    reflex update_variables {
        nombre_poubelles_vides <- max(0, nombre_poubelles - nombre_poubelles_pleines);
    }

    init {
        loop p over: centre {
            create my_point {
                location <- p;
            }
        }
        create Building from: shape_file_maison;
        create Centre_de_traitement from: shape_file_centre_traitement;
        create Camion number: nombre_camion {
            location <- any_location_in(one_of(Centre_de_traitement));
            depart <- location;
        }
        create Citoyen number: nombre_personnes {
            location <- any_location_in(one_of(Building));
            depart <- location;
        }
        create Highway from: shape_file_route;
        create Poubelle from: shape_file_poubelle;
        road_network <- as_edge_graph(Highway);
        nombre_poubelles <- length(Poubelle);
    }
}


species my_point {
    aspect base {
        draw circle(100); // Red color with radius 10
    }
}

species Building {
    rgb couleur <- #gray;

    aspect building {
        draw shape color: couleur depth: 10;
    }
}

species Poubelle {
    bool statut <- true;
    rgb couleur <- #green;
    point position;
    int niveau_poubelle <- 0;
    string etat;
    bool est_occupe <- false;
    string poubelle_etat;

    reflex compter_dechet when: poubelle_etat = "Rempli" {
        compte_dechet <- compte_dechet + 1;
    }
    
    reflex signalisation_centre_de_traitement when: poubelle_etat = "Rempli" {
    	poubelle_remplie <- true;
    }

    aspect poubelle {
        draw shape color: couleur;
        draw image_file(poubelles) size: 50 color: couleur;
    }
}

species Highway {
    rgb couleur <- #gray;

    aspect highway {
        draw shape color: couleur;
    }
}

species Centre_de_traitement {
    rgb couleur <- #yellow;

    aspect centre_de_traitement {
        draw shape color: couleur;
    }

    reflex affectation when: poubelle_remplie = true {
        list<Poubelle> les_poubelles <- list(Poubelle) where ((each.est_occupe = false) and (each.poubelle_etat = "Rempli"));
        if (les_poubelles != []) {
            int nb_poubelle <- length(les_poubelles);
            list<Camion> les_camions <- list(Camion) where ((each.est_occupe = false));
            int nb_camion <- length(les_camions);
            loop i from: 0 to: nb_poubelle - 1 {
                int rn_poubelle <- rnd(nb_poubelle - 1);
                if (les_camions != []) {
                    if (i <= nb_poubelle - 1 and i <= nb_camion - 1) {
                    	nombre_poubelles_pleines <- nombre_poubelles_pleines + 1;
                        les_camions[i].sa_destination <- les_poubelles[i].location;
                        les_poubelles[i].est_occupe <- true;
                        les_camions[i].deja_affecte <- "affecter";
                        les_camions[i].poubelle_instance <- les_poubelles[i];
                    }
                }
            }
        }
    }
}

species Citoyen skills: [moving] {
    rgb couleur <- #black;
    point target <- nil;
    point depart;
    float vitesse <- 5.0;
    Poubelle poubelle_trouver_instance;
    string etat <- 'depart';
    bool peut_marcher <- false;
    int temps_depot_initial <- 15;
    int temps_depot_actuel <- temps_depot_initial;

    aspect citoyen {
        draw image_file(icon) size: 50 color: couleur;
    }

    reflex aller_vers_poubelle when: etat = 'depart' {
        Poubelle poubelle_plus_proche <- first(Poubelle sort_by (self distance_to each.location));
        if (poubelle_plus_proche.etat != "Rempli") {
            peut_marcher <- true;
            poubelle_trouver_instance <- poubelle_plus_proche;
            //poubelle_trouver <- poubelle_plus_proche.location;
            target <- poubelle_plus_proche.location;
            peut_marcher <- true;
            if (location = target) {
                etat <- "arrive";
                peut_marcher <- false;
            }
        } else {
            peut_marcher <- false;
            etat <- 'terminer';
        }
    }

    reflex deposer_dechet when: etat = 'arrive' {
    	nombre_poubelles_en_cours_remplissage <- nombre_poubelles_en_cours_remplissage + 1;
        poubelle_trouver_instance.couleur <- #gray;
        poubelle_trouver_instance.niveau_poubelle <- poubelle_trouver_instance.niveau_poubelle + 1;
        nombre_poubelles_en_cours_remplissage <- nombre_poubelles_en_cours_remplissage + 1;
        if (poubelle_trouver_instance.niveau_poubelle >= 50) {
            poubelle_trouver_instance.couleur <- #red;
            poubelle_trouver_instance.poubelle_etat <- "Rempli";
            nombre_poubelles_pleines <- nombre_poubelles_pleines + 1;
        }
        temps_depot_actuel <- temps_depot_actuel - 1;
        if (temps_depot_actuel <= 0) {
            temps_depot_actuel <- temps_depot_initial;
            peut_marcher <- true;
            etat <- "terminer";
        }
    }

    reflex retour_point_depart when: etat = 'terminer' {
        if (peut_marcher = true) {
            target <- depart;
            temps_depot_actuel <- temps_depot_actuel - 1;
            if (temps_depot_actuel <= 0) {
                temps_depot_actuel <- temps_depot_initial;
                peut_marcher <- true;
                etat <- "depart";
            }
        }
    }

    reflex marcher when: peut_marcher = true {
        do goto target: target speed: vitesse on: road_network recompute_path: false;
        if (location = target) {
            peut_marcher <- false;
        }
    }
}

species Camion skills: [moving] {
    rgb couleur <- #blue;
    point sa_destination <- nil;
    string deja_affecte;
    Poubelle poubelle_instance;
    Centre_de_traitement centre_instance;
    point depart;
    string etat;
    float vitesse <- 10.0;
    bool est_occupe <- false;
    bool peut_rouler <- true;
    bool retour_centre <- false;
    int temps_chargement <- rnd(50, 70, 2);
    int temps_dechargement <- rnd(50, 70, 2);

    aspect camion {
        draw image_file(camions) size: 50 color: couleur;
    }

    reflex aller_vers_poubelle {
        if (deja_affecte = "affecter") {
            est_occupe <- true;
            if (self distance_to sa_destination <= 50) {
                peut_rouler <- false;
                etat <- "chargement";
            }
        }
    }

    reflex chargement_ordure {
        if (etat = "chargement") {
        	nombre_camions_a_destination <- nombre_camions_a_destination + 1;
            int temp <- temps_chargement;
            temps_chargement <- temps_chargement - 1;
            if (temps_chargement <= 0) {
            	nombre_poubelles_pleines <- nombre_poubelles_pleines - 1;
                etat <- "aller_centre";
                temps_chargement <- temp;
                poubelle_instance.couleur <- #green;
                poubelle_instance.poubelle_etat <- "";
                couleur <- #black;
                total_ordures_ramassees <- total_ordures_ramassees + poubelle_instance.niveau_poubelle; // Mise à jour de la quantité totale d'ordures ramassées
                poubelle_instance.niveau_poubelle <- 0; // Réinitialiser le niveau de la poubelle après ramassage
                nombre_trajets <- nombre_trajets + 1; // Mise à jour du nombre de trajets
            }
        }

        if (etat = "aller_centre") {
            list<point> les_centres <- centre;
            point centre_plus_proche <- first(les_centres sort_by (self distance_to each));
            sa_destination <- centre_plus_proche; // Assigner le point du centre le plus proche
            peut_rouler <- true;
            etat <- "retour_centre";
        }

        if (etat = "retour_centre") {
            if (self distance_to sa_destination <= 10) {
                etat <- "dechargement";
            }
        }
    }

    reflex dechargement when: etat = "dechargement" {
        int temp <- temps_dechargement;
        temps_dechargement <- temps_dechargement - 1;
        if (temps_dechargement <= 0) {
            temps_dechargement <- temp;
            temps_chargement <- temp;
            etat <- "";
            est_occupe <- false;
            deja_affecte <- "";
            couleur <- #blue;
            nombre_camions_a_destination <- nombre_camions_a_destination + 1;
        }
    }

    reflex deplacement when: peut_rouler = true {
        do goto target: sa_destination speed: vitesse on: road_network;
        temps_total_deplacement <- temps_total_deplacement + 1; // Mise à jour du temps total en déplacement
        distance_totale_parcourue <- distance_totale_parcourue + (vitesse / 10); // Mise à jour de la distance totale parcourue
    }
}

experiment gestion_urbain type: gui {
    output {
        display city_display type: 3d {
            species Poubelle aspect: poubelle;
            species Highway aspect: highway;
            species Centre_de_traitement aspect: centre_de_traitement;
            species my_point aspect: base;
            species Building aspect: building;
            species Camion aspect: camion;
            species Citoyen aspect: citoyen;
        }

        display "Evaluation des poubelles" type: 2d {
            chart "Evaluation des poubelles" type: pie size: {1, 0.5} position: {0, 0} {
                data "Poubelles Pleines" value: nombre_poubelles_pleines color: #orange;
                data "Poubelles Vides" value: nombre_poubelles - nombre_poubelles_pleines color: #yellow;
                data "Poubelles en cours de remplissage" value: nombre_poubelles_en_cours_remplissage color: #blue;
            }
        }

        display "Evaluation des Camions" type: 2d {
            chart "Evaluation des Camions" type: series size: {1, 0.5} position: {0, 0.5} style: exploded {
                data "Nombre des poubelles vides" value: nombre_poubelles_vides style: line color: #green;
                data "Nombre de camions arrivés" value: nombre_camions_a_destination style: line color: #red;
                data "Nombre de camions vides" value: nombre_camion - nombre_camions_a_destination style: line color: #blue;
            }
        }

        monitor "Nombre de camions" value: nombre_camion color: #blue;
        monitor "Nombre de citoyens" value: nombre_personnes color: #black;

        display "Niveau de ramassage des ordures" type: 2d {
            chart "Niveau de ramassage des ordures" type: series {
                data "Niveau de ramassage des ordures" value: compte_dechet color: #gray;
            }
        }
    }
}
