const translationsFr = <String, String>{
  // Navigation
  'dashboard': 'Tableau de bord',
  'products': 'Produits',
  'orders': 'Commandes',
  'customers': 'Clients',
  'inventory': 'Inventaire',
  'expenses': 'Dépenses',
  'categories': 'Catégories',
  'settings': 'Paramètres',
  'reports': 'Rapports',

  // Dashboard
  'todayRevenue': "Revenu du jour",
  'monthRevenue': 'Revenu du mois',
  'monthProfit': 'Profit du mois',
  'totalOrders': 'Total des commandes',
  'pendingOrders': 'Commandes en attente',
  'unpaidAmount': 'Montant impayé',
  'lowStockItems': 'Articles en stock bas',
  'weeklySales': 'Ventes hebdomadaires',
  'goodMorning': 'Bonjour',
  'goodAfternoon': 'Bon après-midi',
  'goodEvening': 'Bonsoir',

  // Products
  'addProduct': 'Ajouter un produit',
  'editProduct': 'Modifier le produit',
  'productName': 'Nom du produit',
  'sku': 'SKU',
  'description': 'Description',
  'sellingPrice': 'Prix de vente',
  'costPrice': 'Prix de revient',
  'stockQuantity': 'Quantité en stock',
  'lowStockThreshold': 'Seuil de stock bas',
  'category': 'Catégorie',
  'profitMargin': 'Marge bénéficiaire',
  'inStock': 'En stock',
  'lowStock': 'Stock bas',
  'outOfStock': 'Rupture de stock',

  // Orders
  'addOrder': 'Nouvelle commande',
  'editOrder': 'Modifier la commande',
  'orderNumber': 'Commande n°',
  'customer': 'Client',
  'orderItems': 'Articles de la commande',
  'subtotal': 'Sous-total',
  'discount': 'Remise',
  'deliveryFee': 'Frais de livraison',
  'tax': 'Taxe',
  'total': 'Total',
  'amountPaid': 'Montant payé',
  'notes': 'Notes',
  'paymentMethod': 'Mode de paiement',
  'deliveryAddress': 'Adresse de livraison',
  'estimatedDelivery': 'Livraison estimée',
  'returnOrder': 'Retourner la commande',

  // Order status
  'pending': 'En attente',
  'confirmed': 'Confirmée',
  'shipped': 'Expédiée',
  'completed': 'Terminée',
  'cancelled': 'Annulée',

  // Payment status
  'unpaid': 'Impayé',
  'partial': 'Partiel',
  'paid': 'Payé',

  // Payment methods
  'cash': 'Espèces',
  'card': 'Carte',
  'mfs': 'MFS',
  'bank': 'Banque',
  'other': 'Autre',

  // Customers
  'addCustomer': 'Ajouter un client',
  'editCustomer': 'Modifier le client',
  'customerName': 'Nom',
  'phone': 'Téléphone',
  'address': 'Adresse',
  'totalSpent': 'Total dépensé',
  'outstandingBalance': 'Solde impayé',
  'purchaseHistory': 'Historique des achats (6 mois)',

  // Inventory
  'stockAdjustment': 'Ajustement de stock',
  'stockMovements': 'Mouvements de stock',
  'adjustQty': 'Ajuster la quantité',
  'reason': 'Raison',

  // Expenses
  'addExpense': 'Ajouter une dépense',
  'expenseTitle': 'Titre de la dépense',
  'amount': 'Montant',
  'expenseCategory': 'Catégorie',
  'date': 'Date',

  // Settings
  'shopName': 'Nom de la boutique',
  'currencySymbol': 'Symbole monétaire',
  'googleAccount': 'Compte Google',
  'backupToDrive': 'Sauvegarder sur Drive',
  'restoreFromDrive': 'Restaurer depuis Drive',
  'lastBackup': 'Dernière sauvegarde',
  'appVersion': 'Version de l\'application',
  'defaultLowStockThreshold': 'Seuil de stock bas par défaut',
  'clearAllData': 'Effacer toutes les données',
  'signIn': 'Se connecter',
  'signOut': 'Se déconnecter',
  'taxRate': 'Taux de taxe (%)',
  'theme': 'Thème',
  'light': 'Clair',
  'dark': 'Sombre',
  'system': 'Système',
  'language': 'Langue',

  // Actions
  'save': 'Enregistrer',
  'cancel': 'Annuler',
  'delete': 'Supprimer',
  'edit': 'Modifier',
  'confirm': 'Confirmer',
  'yes': 'Oui',
  'no': 'Non',
  'add': 'Ajouter',
  'search': 'Rechercher',
  'filter': 'Filtrer',
  'share': 'Partager',
  'print': 'Imprimer',
  'markAsPaid': 'Marquer comme payé',
  'exportCsv': 'Exporter CSV',
  'importCsv': 'Importer CSV',

  // Messages
  'deleteConfirmation': 'Êtes-vous sûr de vouloir supprimer ceci ?',
  'clearDataConfirmation':
      'Cela supprimera définitivement toutes vos données. Cette action est irréversible. Êtes-vous sûr ?',
  'savedSuccessfully': 'Enregistré avec succès',
  'deletedSuccessfully': 'Supprimé avec succès',
  'errorOccurred': 'Une erreur est survenue. Veuillez réessayer.',
  'backupSuccess': 'Sauvegarde terminée avec succès',
  'restoreSuccess': 'Données restaurées avec succès',
  'noDataFound': 'Aucune donnée trouvée',
  'addFirstProduct': 'Ajoutez votre premier produit pour commencer',
  'addFirstOrder': 'Aucune commande. Créez votre première commande !',
  'addFirstCustomer': 'Ajoutez des clients pour suivre leurs commandes',
  'noExpenses': 'Aucune dépense enregistrée',
  'noStockMovements': 'Aucun mouvement de stock enregistré',

  // Reports
  'totalRevenue': 'Revenu total',
  'totalProfit': 'Profit total',
  'totalExpenses': 'Dépenses totales',
  'avgOrderValue': 'Valeur moyenne des commandes',
  'topProducts': 'Meilleurs produits par revenu',
  'topProductsByQty': 'Meilleurs produits par quantité',
  'topCustomers': 'Meilleurs clients',
  'salesByCategory': 'Ventes par catégorie',

  // Recurring
  'recurringOrder': 'Commande récurrente',
  'repeatEvery': 'Répéter tous les',
  'days': 'jours',

  // Delivery
  'delivery': 'Livraison',
  'markDelivered': 'Marquer comme livré',
  'delivered': 'Livré',

  // Variants
  'variants': 'Variantes',
  'addVariant': 'Ajouter une variante',
  'variantName': 'Attribut (ex. Taille)',
  'variantValue': 'Valeur (ex. Grand)',
  'priceAdjustment': 'Prix +/-',
};
