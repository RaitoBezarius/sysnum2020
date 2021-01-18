---
title: Présentation du projet de sysnum
author: Ryan \textsc{Lahfa}, Constantin \textsc{Gierczak-Galle}, Julien \textsc{Marquet}, Gabriel \textsc{Doriath Döhler}
lang: fr
advanced-maths: true
advanced-cs: true
theme: metropolis
---

# Introduction

## Car c'est notre projet !

Le projet se divise en deux sous-projets :

- Le processeur Minecraft avec l'ISA V-RISC-V^[Invention de cerveaux malades.] ;
- Le processeur RISC-V écrit en System Verilog et simulé avec Verilator

## Plan pour Minecraft

> - Motivations
> - Redstone
> - ISA
> - Détails d'implémentation

## Plan pour RISC-V

> - Fonctionnalités principales du processeur: extensions, entrées-sorties
> - Prototypes
> - Icarus Verilog → Verilator et Verilog → System Verilog
> - Caches, MMU 
> - Wishbone
> - Vérification formelle avec SymbiFlow
> - Contrôleur VGA

# Minecraft

# Le processeur RISC-V (Sakaido, le brillant)

## Fonctionnalités principales

Il s'agit d'un processeur RISC-V qui implémente RV32I^[RV32IM était disponible à un moment].
