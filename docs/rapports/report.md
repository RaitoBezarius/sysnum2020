---
title: Rapport de projet de sysnum
author: Ryan \textsc{Lahfa}, Constantin \textsc{Gierczak-Galle}, Julien \textsc{Marquet}, Gabriel \textsc{Doriath Döhler}
abstract: 
toc: true
advanced-maths: true
advanced-cs: true
numbersections: true
---

## Pipeline

Ce processeur implémente la pipeline standard en 5 étages :
 * Récupération de l'instruction
 * Décodage
 * Exécution
 * Accès mémoire
 * Écriture retour

Nous avons choisi d'optimiser la pipeline en mettant en place un système de
forwarding entre les étages.
Grâce à l'architecture RISC-V, il suffisait d'implémenter le forwarding entre l'étage EXE
et les étages MEM et WB : chaque étage déclare l'éventuel registre dans lequel il écrit
et les autres obtiennent (grâce à l'unité de forwarding) une vue sur l'état des registres
qui correspond à ce que sera l'état des registres _après_ que les étages suivant
auront écrit leurs données.

> On pourrait éviter de relier l'étage WB à l'unité de forwarding,
> mais des contraintes techniques liées au timing sur Verilog nous ont poussés
> à choisir cette stratégie, même si elle implique d'utiliser un peu plus
> de circuits.

L'ISA RISC-V est conçue pour permettre d'impélenter raisonnablement facilement
cette pipeline, nous ne nous sommes donc pas heurtés à de trop gros problèmes
(ce qui ne nous a cependant pas empêchés de passer quelques moments à nous
battre contre Verilog pour comprendre comment faire exécuter les opérations
logiques dans l'ordre prévu).

